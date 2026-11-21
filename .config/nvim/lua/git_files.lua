local M = {}
local roots = {}
local refreshing, pending
local revisions = {}

function M.run(directory, args, callback, options)
    local command = vim.list_extend({ 'git', '--literal-pathspecs' }, args)
    local done = vim.schedule_wrap(callback)
    local ok, process = pcall(vim.system, command, vim.tbl_extend('force', {
        cwd = directory,
        env = { LC_ALL = 'C', GIT_OPTIONAL_LOCKS = '0' },
    }, options or {}), done)
    if ok then return process end
    done { code = 1, stdout = '', stderr = tostring(process) }
end

function M.directory(path)
    local directory = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
    while vim.fn.isdirectory(directory) == 0 and directory ~= vim.fs.dirname(directory) do
        directory = vim.fs.dirname(directory)
    end
    return directory
end

function M.root(directory, callback)
    directory = vim.uv.fs_realpath(directory) or directory
    local cached = roots[directory]
    if cached and cached.waiters then
        table.insert(cached.waiters, callback)
        return
    end
    if cached and vim.uv.now() - cached.time < (cached.root and 30000 or 1500) then
        callback(cached.root, cached.error)
        return
    end
    cached = { waiters = { callback } }
    roots[directory] = cached
    M.run(directory, { 'rev-parse', '--show-toplevel' }, function(output)
        cached.time = vim.uv.now()
        if output.code == 0 then
            cached.root = output.stdout:gsub('\n$', '')
        elseif not output.stderr:find('not a git repository', 1, true)
            and not output.stderr:find('must be run in a work tree', 1, true) then
            cached.error = output
        end
        local waiters = cached.waiters
        cached.waiters = nil
        for _, waiter in ipairs(waiters) do waiter(cached.root, cached.error) end
    end)
end

function M.read(root, path, base, callback, cache)
    cache = cache or {}
    -- NUL-delimited batch lookup handles absent/unborn revisions and unusual
    -- filenames without parsing localized fatal messages. Blob IDs are immutable.
    M.run(root, { 'cat-file', '--batch-check=%(objectname) %(objecttype)', '-Z' }, function(info)
        if info.code ~= 0 then callback(nil, vim.trim(info.stderr)); return end
        if info.stdout:sub(-9) == ' missing\0' then callback('', nil, false); return end
        local object, kind = info.stdout:match('^(%x+) (%S+)%z$')
        if kind ~= 'blob' then callback(nil, 'Cannot revert directories'); return end
        if cache.object == object and cache.text then callback(cache.text, nil, true); return end
        M.run(root, { 'cat-file', 'blob', object }, function(output)
            if output.code ~= 0 then callback(nil, vim.trim(output.stderr)); return end
            cache.object, cache.text = object, output.stdout
            callback(output.stdout, nil, true)
        end)
    end, { stdin = base .. ':' .. path .. '\0' })
end

function M.base(entry)
    return (entry.section == 'staged' or entry.conflict) and 'HEAD' or ''
end

-- Review and summary must use the same blob, including an uncommitted rename.
function M.reference(root, entry, callback, cache)
    cache = cache or {}
    cache.current, cache.previous = cache.current or {}, cache.previous or {}
    M.read(root, entry.path, M.base(entry), function(text, err, present)
        if not err and not present and entry.rename then
            M.read(root, entry.old_path, M.base(entry), callback, cache.previous)
        else
            callback(text, err, present)
        end
    end, cache.current)
end

function M.contents(buf)
    local ending = vim.bo[buf].fileformat == 'dos' and '\r\n' or '\n'
    local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), ending)
        .. (vim.bo[buf].endofline and ending or '')
    return (vim.bo[buf].bomb and '\239\187\191' or '') .. text
end

function M.normalize(text, buf)
    if not buf or vim.bo[buf].fileformat == 'dos' then text = text:gsub('\r\n', '\n') end
    if buf and vim.bo[buf].bomb then text = text:gsub('^\239\187\191', '') end
    return text
end

function M.error(message)
    vim.api.nvim_echo({ { 'ERROR: ' .. vim.trim(message), 'GitError' } }, true, {})
end

function M.invalidate(root)
    revisions[root] = (revisions[root] or 0) + 1
end

function M.changes(text)
    local result = {}
    local records = vim.split(text, '\0', { plain = true, trimempty = true })
    local index = 1
    while index <= #records do
        local record = records[index]
        local x, y, path = record:sub(1, 1), record:sub(2, 2), record:sub(4)
        local old_path
        if x == 'R' or x == 'C' or y == 'R' or y == 'C' then
            index = index + 1
            old_path = records[index]
        end
        table.insert(result, {
            x = x, y = y, path = path, old_path = old_path,
            conflict = x == 'U' or y == 'U' or x .. y == 'AA' or x .. y == 'DD',
        })
        index = index + 1
    end
    return result
end

local function statuses(text)
    local result = {}
    for _, change in ipairs(M.changes(text)) do
        local x, y, path = change.x, change.y, change.path
        if x == '?' then
            result[path] = '?'
        elseif x == '!' then
            result[path] = 'I'
        elseif change.conflict then
            result[path] = 'U'
        else
            result[path] = y ~= ' ' and y or x
        end
    end
    return result
end

local function apply(files, state)
    local changed = false
    for _, file in ipairs(files) do
        if vim.api.nvim_buf_is_valid(file.buf) and vim.api.nvim_buf_get_name(file.buf) == file.name then
            local status = file.relative and state[file.relative] or nil
            if file.relative and not status and not vim.uv.fs_stat(file.path) then status = '?' end
            if vim.b[file.buf].git_file_status ~= status then
                vim.b[file.buf].git_file_status = status
                changed = true
            end
        end
    end
    if changed then vim.cmd 'redrawtabline' end
end

-- Refresh displayed files in every tab, independently of the Git sidebar.
-- Rendering reads buffer-local cached results and never starts Git processes.
function M.refresh(full_roots, callback)
    full_roots, callback = full_roots or {}, callback or function() end
    if refreshing then
        pending = pending or { {}, {} }
        for root in pairs(full_roots) do pending[1][root] = true end
        table.insert(pending[2], callback)
        return
    end
    refreshing = true
    local results = {}
    local function finish()
        refreshing = false
        callback(results)
        if pending then
            local next_refresh = pending
            pending = nil
            vim.schedule(function()
                M.refresh(next_refresh[1], function(data)
                    for _, done in ipairs(next_refresh[2]) do done(data) end
                end)
            end)
        end
    end
    local directories, seen = {}, {}
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local bufnr = vim.api.nvim_win_get_buf(win)
        local name = vim.api.nvim_buf_get_name(bufnr)
        if not seen[bufnr] and vim.bo[bufnr].buftype == '' and name ~= ''
            and not name:match('^%a[%w+.-]*://') and vim.fn.isdirectory(name) == 0
            and vim.api.nvim_win_get_config(win).relative == '' then
            seen[bufnr] = true
            local directory = M.directory(name)
            directories[directory] = directories[directory] or {}
            table.insert(directories[directory], {
                buf = bufnr, name = name,
                path = vim.fs.joinpath(vim.uv.fs_realpath(directory) or directory, vim.fs.relpath(directory, name)),
            })
        end
    end
    local remaining = vim.tbl_count(directories)
    local repositories = {}
    for root in pairs(full_roots) do repositories[root] = {} end
    local function query()
        local outstanding = vim.tbl_count(repositories)
        if outstanding == 0 then finish(); return end
        for root, files in pairs(repositories) do
            local full = full_roots[root] == true
            local revision = revisions[root]
            local args = { 'status', '--porcelain=v1', '-z', '--untracked-files=all' }
            if not full then
                table.insert(args, '--ignored=traditional')
                table.insert(args, '--')
                for _, file in ipairs(files) do table.insert(args, file.relative) end
            end
            local function complete(output, state)
                if revisions[root] == revision then
                    results[root] = { raw = output.stdout, full = full, error = output.code ~= 0 and output or nil }
                    if state then apply(files, state) end
                end
            end
            M.run(root, args, function(output)
                local function done(state)
                    complete(output, state)
                    outstanding = outstanding - 1
                    if outstanding == 0 then finish() end
                end
                if output.code ~= 0 or revisions[root] ~= revision then done(); return end
                local state = statuses(output.stdout)
                local ignored = { 'ls-files', '--others', '--ignored', '--exclude-standard', '-z', '--' }
                if full then
                    for _, file in ipairs(files) do
                        if not state[file.relative] then table.insert(ignored, file.relative) end
                    end
                end
                if #ignored == 6 then done(state); return end
                M.run(root, ignored, function(ignored_output)
                    if ignored_output.code ~= 0 then done(); return end
                    for path in vim.gsplit(ignored_output.stdout, '\0', { plain = true, trimempty = true }) do state[path] = 'I' end
                    done(state)
                end)
            end)
        end
    end
    if remaining == 0 then query(); return end
    for directory, files in pairs(directories) do
        M.root(directory, function(root)
            if root then
                repositories[root] = repositories[root] or {}
                for _, file in ipairs(files) do
                    file.relative = vim.fs.relpath(root, file.path)
                    table.insert(repositories[root], file)
                end
            else
                apply(files, {})
            end
            remaining = remaining - 1
            if remaining == 0 then query() end
        end)
    end
end

return M
