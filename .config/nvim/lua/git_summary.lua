local M = {}
local files, uv = require 'git_files', vim.uv
local active
local group = vim.api.nvim_create_augroup('GitDiffSummary', { clear = true })

function M.close()
    local s = active
    active = nil
    if not s then return end
    if s.win and vim.api.nvim_win_is_valid(s.win) then vim.api.nvim_win_close(s.win, true) end
end

local function working(path)
    local stat = uv.fs_stat(path)
    local buf = vim.fn.bufnr(path)
    if buf >= 0 and vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
        if not vim.bo[buf].modified and (not stat or stat.size == 0) then return '', nil, false, buf end
        return files.contents(buf), nil, vim.bo[buf].binary, buf
    end
    if not stat then return '' end
    local fd, err = uv.fs_open(path, 'r', 0)
    if not fd then return nil, err end
    local text, why = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    return text, why
end

local function render(s, output)
    if active ~= s or not vim.api.nvim_win_is_valid(s.owner) then return end
    local flat = {}
    for _, line in ipairs(output) do vim.list_extend(flat, vim.split(line, '\n', { plain = true })) end
    output = flat
    local width = 16
    for _, line in ipairs(output) do width = math.max(width, vim.fn.strdisplaywidth(line)) end
    width = math.min(width, math.max(1, vim.o.columns - 4))
    local height = math.min(#output, math.max(1, vim.o.lines - 4))
    local pos = vim.api.nvim_win_get_position(s.owner)
    local view = vim.api.nvim_win_call(s.owner, vim.fn.winsaveview)
    local config = { relative = 'editor', row = math.max(0, math.min(pos[1] + s.row - view.topline + 1, vim.o.lines - height - 3)),
        col = math.min(pos[2] + 1, math.max(0, vim.o.columns - width - 2)), width = width, height = height,
        style = 'minimal', border = 'rounded', title = 'Diff summary', focusable = false }
    if not s.win then
        s.buf = vim.api.nvim_create_buf(false, true)
        vim.bo[s.buf].bufhidden, vim.bo[s.buf].filetype = 'wipe', 'gitdiffsummary'
        s.win = vim.api.nvim_open_win(s.buf, false, config)
        vim.wo[s.win].winhighlight = 'NormalFloat:NvimTreeNormal,FloatBorder:NvimTreeNormalFloatBorder'
    else
        vim.api.nvim_win_set_config(s.win, config)
    end
    vim.bo[s.buf].modifiable = true
    vim.api.nvim_buf_set_lines(s.buf, 0, -1, false, output)
    vim.bo[s.buf].modifiable, vim.bo[s.buf].modified = false, false
end

function M.open(root, entry, owner)
    local key = entry.section .. '\0' .. entry.path
    if active and active.owner == owner and active.key == key then M.close(); return end
    M.close()
    local s = { owner = owner, row = vim.api.nvim_win_get_cursor(owner)[1], key = key }
    active = s
    render(s, { 'Loading diff summary…' })
    if entry.submodule then
        local args = { 'diff', '--submodule=log', '--ignore-submodules=none', '--no-ext-diff', '--no-textconv', '--no-color' }
        if entry.section == 'staged' then args[#args + 1] = '--cached' end
        vim.list_extend(args, { '--', entry.path })
        if entry.rename then args[#args + 1] = entry.old_path end
        files.run(root, args, function(output)
            local text = output.code == 0 and vim.trim(output.stdout) or ('ERROR: ' .. vim.trim(output.stderr))
            render(s, { vim.fn.strtrans(entry.path), text ~= '' and text or 'No submodule pointer change' })
        end)
        return
    end
    files.reference(root, entry, function(reference, err)
        if active ~= s then return end
        if err then render(s, { 'ERROR: ' .. err }); return end
        local text, why, binary, buf = working(vim.fs.joinpath(root, entry.path))
        if not text then render(s, { 'ERROR: ' .. tostring(why) }); return end
        local states = { M = 'Modified', A = 'Added', D = 'Deleted', R = 'Renamed', C = 'Copied',
            ['?'] = 'Untracked', U = 'Conflicted', T = 'Type changed' }
        local output = { vim.fn.strtrans(entry.path), 'Status: ' .. (states[entry.status] or entry.status) .. ' (' .. entry.section .. ')',
            'Compare: ' .. (files.base(entry) == 'HEAD' and 'HEAD' or 'Index') .. ' → buffer' }
        if entry.rename and entry.old_path then table.insert(output, 2, 'From: ' .. vim.fn.strtrans(entry.old_path)) end
        if binary or reference:find('\0', 1, true) or text:find('\0', 1, true) then
            output[#output + 1] = 'Binary diff — line counts unavailable'
        else
            local hunks = vim.text.diff(files.normalize(reference, buf), files.normalize(text, buf), { result_type = 'indices' })
            local added, removed = 0, 0
            for _, hunk in ipairs(hunks) do added, removed = added + hunk[4], removed + hunk[2] end
            vim.list_extend(output, { 'Added: ' .. added, 'Removed: ' .. removed, 'Hunks: ' .. #hunks })
        end
        render(s, output)
    end)
end

vim.api.nvim_create_autocmd('CursorMoved', { group = group, callback = function()
    if active and vim.api.nvim_get_current_win() == active.owner and vim.fn.line('.') ~= active.row then M.close() end
end })
vim.api.nvim_create_autocmd({ 'WinLeave', 'BufLeave', 'TabLeave' }, { group = group, callback = function()
    if active and vim.api.nvim_get_current_win() == active.owner then M.close() end
end })
vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(event)
    if active and (tonumber(event.match) == active.owner or tonumber(event.match) == active.win) then M.close() end
end })
vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = M.close })

return M
