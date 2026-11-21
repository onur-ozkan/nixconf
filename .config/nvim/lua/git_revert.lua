local M = {}
local git_files = require 'git_files'

-- Assign each current line its corresponding reference lines. Unlike a partial
-- MiniDiff reset, this never replaces unselected current lines with a whole hunk.
function M.lines(reference, current, first, last)
    local original = vim.split(reference, '\n', { plain = true })
    if original[#original] == '' then table.remove(original) end
    local base = #original > 0 and table.concat(original, '\n') .. '\n' or ''
    local coarse = vim.text.diff(base, table.concat(current, '\n') .. '\n', {
        result_type = 'indices', algorithm = 'histogram', indent_heuristic = true,
    })
    local hunks = {}
    for _, hunk in ipairs(coarse) do
        local rs, rc, bs, bc = unpack(hunk)
        if rc > 0 and bc > 0 and rc ~= bc and rc + bc <= 60 then
            -- Separate inserted/deleted lines from adjacent replacements. Keep
            -- equal-sized blocks paired directly, including unrelated Unicode.
            local old = table.concat(vim.list_slice(original, rs, rs + rc - 1), '\n') .. '\n'
            local new = table.concat(vim.list_slice(current, bs, bs + bc - 1), '\n') .. '\n'
            for _, part in ipairs(vim.text.diff(old, new, { result_type = 'indices', linematch = 60 })) do
                table.insert(hunks, { rs + part[1] - 1, part[2], bs + part[3] - 1, part[4] })
            end
        else
            table.insert(hunks, hunk)
        end
    end
    local replace, insert = {}, {}
    for _, hunk in ipairs(hunks) do
        local ref_start, ref_count, buf_start, buf_count = unpack(hunk)
        if buf_count == 0 then
            -- Deleted virtual lines belong to the adjacent real anchor line.
            local anchor = math.max(buf_start, 1)
            if first <= anchor and anchor <= last then
                insert[buf_start] = vim.list_slice(original, ref_start, ref_start + ref_count - 1)
            end
        else
            for line = math.max(first, buf_start), math.min(last, buf_start + buf_count - 1) do
                local offset = line - buf_start
                local count = offset < ref_count and 1 or 0
                -- A contraction's remaining deleted reference lines are attached
                -- to its final current line; expansions' extra lines are additions.
                if line == buf_start + buf_count - 1 then count = math.max(ref_count - offset, 0) end
                replace[line] = count > 0 and vim.list_slice(original, ref_start + offset, ref_start + offset + count - 1) or {}
            end
        end
    end
    local result = vim.deepcopy(insert[0] or {})
    for line, text in ipairs(current) do
        vim.list_extend(result, replace[line] or { text })
        vim.list_extend(result, insert[line] or {})
    end
    return #result > 0 and result or { '' }
end

local function read_changes(root, entries, callback)
    local args = { 'status', '--porcelain=v1', '-z', '--untracked-files=all', '--' }
    for _, entry in ipairs(entries) do
        table.insert(args, entry.path)
        if entry.old_path then table.insert(args, entry.old_path) end
    end
    git_files.run(root, args, function(output)
        if output.code ~= 0 then callback(nil, vim.trim(output.stderr)); return end
        local by_path = {}
        for _, change in ipairs(git_files.changes(output.stdout)) do
            by_path[change.path] = change
            if change.old_path then by_path[change.old_path] = change end
        end
        local changes = {}
        for _, entry in ipairs(entries) do
            local change = by_path[entry.path]
            if change and change.y == ' ' and change.x ~= ' ' then
                callback(nil, 'Cannot revert staged changes')
                return
            end
            if change and change.conflict then
                callback(nil, 'Cannot revert conflicted changes')
                return
            end
            if not change or change.path ~= entry.path then
                callback(nil, 'File status changed; try X again')
                return
            end
            local stat = vim.uv.fs_lstat(vim.fs.joinpath(root, change.path))
            if stat and stat.type == 'directory' then
                callback(nil, 'Cannot revert directories')
                return
            end
            table.insert(changes, change)
        end
        callback(changes)
    end)
end

local function targets(changes)
    local restore, delete = {}, {}
    for _, change in ipairs(changes) do
        if change.x == '?' or change.y == 'C' then
            table.insert(delete, change.path)
        elseif change.y == 'R' then
            table.insert(restore, change.old_path)
            table.insert(delete, change.path)
        else
            table.insert(restore, change.path)
        end
    end
    return restore, delete
end

local function buffers(root, restore, delete)
    local paths, result = {}, {}
    for _, path in ipairs(restore) do paths[vim.fs.joinpath(root, path)] = 'restore' end
    for _, path in ipairs(delete) do paths[vim.fs.joinpath(root, path)] = 'delete' end
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == '' then
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name ~= '' then
                -- Resolve directory aliases, but retain symlink filenames: deleting
                -- an untracked symlink must not close its target's editor buffer.
                local directory = vim.fs.dirname(name)
                local path = vim.fs.joinpath(vim.uv.fs_realpath(directory) or directory, vim.fs.basename(name))
                local action = paths[path]
                if action then
                    table.insert(result, { buf = bufnr, name = name, action = action,
                        tick = vim.api.nvim_buf_get_changedtick(bufnr), modified = vim.bo[bufnr].modified })
                end
            end
        end
    end
    return result
end

local function reload(loaded)
    local failure
    for _, file in ipairs(loaded) do
        if vim.api.nvim_buf_is_loaded(file.buf) and vim.api.nvim_buf_get_name(file.buf) == file.name then
            local ok, err = pcall(function()
                if vim.api.nvim_buf_get_changedtick(file.buf) ~= file.tick then
                    error('File reverted on disk; newer buffer edits were kept: ' .. file.name, 0)
                end
                if file.action == 'delete' then
                    if vim.uv.fs_lstat(file.name) then error('File was not deleted: ' .. file.name) end
                    vim.api.nvim_buf_delete(file.buf, { force = true })
                else
                    vim.api.nvim_buf_call(file.buf, function() vim.cmd 'silent edit!' end)
                end
            end)
            if not ok then failure = failure or tostring(err) end
        end
    end
    return failure
end

function M.files(root, entries, done, valid)
    for _, entry in ipairs(entries) do
        if entry.section == 'staged' then done('Cannot revert staged changes'); return end
    end
    if #entries == 0 then done(); return end
    read_changes(root, entries, function(changes, err)
        if err then done(err); return end
        if not valid() then done(); return end
        local restore, delete = targets(changes)
        local loaded = buffers(root, restore, delete)
        local message = { 'Revert unstaged changes to these files?' }
        for _, path in ipairs(restore) do table.insert(message, '  ' .. vim.fn.strtrans(path)) end
        for _, path in ipairs(delete) do table.insert(message, '  DELETE untracked: ' .. vim.fn.strtrans(path)) end
        for _, file in ipairs(loaded) do
            if file.modified then
                table.insert(message, '\nThis also discards unsaved edits in these files.')
                break
            end
        end
        local ok, answer = pcall(vim.fn.confirm, table.concat(message, '\n'), '&Cancel\n&Revert', 1)
        if not ok then done(tostring(answer)); return end
        if answer ~= 2 or not valid() then done(); return end
        -- The index or selection may have changed while the prompt was open.
        read_changes(root, entries, function(latest, status_err)
            if status_err then done(status_err); return end
            if not valid() then done(); return end
            if not vim.deep_equal(changes, latest) then done('File status changed; try X again'); return end
            for _, file in ipairs(loaded) do
                if vim.api.nvim_buf_is_loaded(file.buf) and (vim.api.nvim_buf_get_name(file.buf) ~= file.name
                    or vim.api.nvim_buf_get_changedtick(file.buf) ~= file.tick) then
                    done('Buffer changed; try X again')
                    return
                end
            end
            local function clean()
                if #delete == 0 then done(reload(loaded)); return end
                -- Git itself excludes tracked and ignored files, even if another
                -- process stages a formerly-untracked path after validation.
                local args = vim.list_extend({ 'clean', '-f', '--' }, delete)
                git_files.run(root, args, function(output)
                    local reload_error = reload(loaded)
                    done(output.code ~= 0 and vim.trim(output.stderr) or reload_error)
                end)
            end
            if #restore == 0 then clean(); return end
            local args = vim.list_extend({ 'restore', '--worktree', '--' }, restore)
            git_files.run(root, args, function(output)
                if output.code ~= 0 then done(vim.trim(output.stderr)); return end
                clean()
            end)
        end)
    end)
end

return M
