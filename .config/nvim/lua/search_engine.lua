local M = {}
local uv = vim.uv

local function value(data)
    return data.text or vim.base64.decode(data.bytes)
end

local function signature(stat)
    return stat and { stat.dev, stat.ino, stat.size, stat.mtime.sec, stat.mtime.nsec,
        stat.ctime.sec, stat.ctime.nsec }
end

function M.apply_text(text, changes)
    local result, offset = {}, 0
    local dos = text:find('\r\n', 1, true) and not text:gsub('\r\n', ''):find('\n', 1, true)
    for _, change in ipairs(changes) do
        assert(change.offset >= offset and text:sub(change.offset + 1, change.offset + #change.match) == change.match,
            'File changed since search; search again')
        local replacement = change.replacement
        if dos then replacement = replacement:gsub('\r\n', '\n'):gsub('\n', '\r\n') end
        result[#result + 1] = text:sub(offset + 1, change.offset) .. replacement
        offset = change.offset + #change.match
    end
    result[#result + 1] = text:sub(offset + 1)
    return table.concat(result)
end

function M.search(cwd, fields, options, callback)
    local args = { 'rg', '--json', '--hidden', '--multiline', '--color=never',
        options.case and '--case-sensitive' or '--ignore-case' }
    if options.regex then table.insert(args, '--engine=auto') else table.insert(args, '--fixed-strings') end
    if options.word then table.insert(args, '--word-regexp') end
    if options.filters then
        for _, name in ipairs({ 'include', 'exclude' }) do
            for glob in fields[name]:gmatch('[^\n]+') do
                glob = vim.trim(glob)
                if glob ~= '' then table.insert(args, '--glob=' .. (name == 'exclude' and '!' or '') .. glob) end
            end
        end
    end
    vim.list_extend(args, { '--glob=!.git', '--glob=!.nvim-search-*' })
    if options.replace then
        local replacement = fields.replacement
        if options.regex then
            local escapes = { n = '\n', r = '\r', t = '\t', ['\\'] = '\\' }
            replacement = replacement:gsub('\\([nrt\\])', escapes)
        else
            replacement = replacement:gsub('%$', '$$')
        end
        table.insert(args, '--replace=' .. replacement)
    end
    vim.list_extend(args, { '--regexp', fields.query, '--', '.' })
    local files, count, carry, truncated, failure, job = {}, 0, '', false
    local function cancel() if job then pcall(job.kill, job, 15) end end
    local function record(line)
        local event = vim.json.decode(line)
        local data = event.data
        if event.type ~= 'match' and event.type ~= 'end' then return end
        local name = value(data.path):gsub('^%./', '')
        if event.type == 'end' then
            if data.binary_offset ~= nil and data.binary_offset ~= vim.NIL and files[name] then
                count = count - files[name].count; files[name] = nil
            end
            return
        end
        local file = files[name]
        if not file then
            file = { name = name, path = vim.fs.joinpath(cwd, name), count = 0, changes = {}, fragments = {} }
            file.signature = signature(uv.fs_stat(file.path))
            files[name] = file
        end
        local fragment = { line = data.line_number, text = value(data.lines), changes = {} }
        for _, match in ipairs(data.submatches) do
            if count == 2000 then truncated = true; cancel(); break end
            local before = fragment.text:sub(1, match.start)
            local _, newlines = before:gsub('\n', '')
            local change = { offset = data.absolute_offset + match.start, match = value(match.match),
                replacement = match.replacement and value(match.replacement),
                line = data.line_number + newlines, column = #(before:match('[^\n]*$') or '') }
            table.insert(file.changes, change)
            table.insert(fragment.changes, { offset = match.start, match = change.match, replacement = change.replacement })
            count, file.count = count + 1, file.count + 1
        end
        table.insert(file.fragments, fragment)
    end
    job = vim.system(args, { cwd = cwd, stdout = vim.schedule_wrap(function(err, chunk)
        if failure or truncated then return end
        if err then failure = tostring(err); cancel(); return end
        if not chunk then return end
        carry = carry .. chunk
        while true do
            local ending = carry:find('\n', 1, true)
            if not ending then break end
            local line = carry:sub(1, ending - 1)
            carry = carry:sub(ending + 1)
            local ok, parse_error = pcall(record, line)
            if not ok then failure = tostring(parse_error); cancel(); break end
            if truncated then break end
        end
    end) }, vim.schedule_wrap(function(output)
        if not truncated and output.code ~= 0 and output.code ~= 1 then failure = failure or vim.trim(output.stderr) end
        local result = {}
        for _, file in pairs(files) do if file.count > 0 then table.insert(result, file) end end
        table.sort(result, function(a, b) return a.name < b.name end)
        callback({ files = result, count = count, truncated = truncated, error = failure })
    end))
    return cancel
end

local function buffers(path)
    local result = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == ''
            and uv.fs_realpath(vim.api.nvim_buf_get_name(buf)) == path then
            assert(not vim.bo[buf].modified, 'Unsaved edits in target file; save before replacing')
            assert(vim.bo[buf].modifiable and not vim.bo[buf].readonly, 'Target buffer is read-only')
            result[#result + 1] = { buf = buf, tick = vim.api.nvim_buf_get_changedtick(buf) }
        end
    end
    return result
end

local function read(path)
    local fd = assert(uv.fs_open(path, 'r', 0))
    local stat = assert(uv.fs_fstat(fd))
    local text, err = uv.fs_read(fd, stat.size, 0)
    uv.fs_close(fd)
    assert(text, err)
    return text, stat
end

local function unchanged(file)
    assert(vim.deep_equal(signature(uv.fs_stat(file.path)), file.signature), 'File changed since search; search again')
    buffers(uv.fs_realpath(file.path) or file.path)
    for _, ref in ipairs(file.buffers) do
        if vim.api.nvim_buf_is_loaded(ref.buf) then
            assert(vim.api.nvim_buf_get_changedtick(ref.buf) == ref.tick, 'Buffer changed; search again')
        end
    end
end

function M.replace(files, valid, callback)
    local prepared, completed = {}, 0
    local ok, err = pcall(function()
        for _, file in ipairs(files) do
            local text, stat = read(file.path)
            local item = vim.tbl_extend('force', file, { buffers = buffers(uv.fs_realpath(file.path) or file.path),
                text = M.apply_text(text, file.changes), mode = stat.mode % 512 })
            unchanged(item)
            assert(uv.fs_access(file.path, 'W'), 'Target file is read-only')
            table.insert(prepared, item)
        end
    end)
    if not ok then callback(tostring(err), 0); return end
    local function next_file()
        if not valid() then callback('Replacement stopped', completed); return end
        local file = prepared[completed + 1]
        if not file then callback(nil, completed); return end
        local temporary
        local success, write_error = pcall(function()
            unchanged(file)
            local refs = buffers(uv.fs_realpath(file.path) or file.path)
            local fd, path = uv.fs_mkstemp(vim.fs.joinpath(vim.fs.dirname(file.path), '.nvim-search-XXXXXX'))
            assert(fd, path)
            temporary = path
            local wrote, why = pcall(function()
                local offset = 0
                while offset < #file.text do
                    local size = assert(uv.fs_write(fd, file.text:sub(offset + 1), offset))
                    assert(size > 0, 'Could not write replacement')
                    offset = offset + size
                end
                assert(uv.fs_fchmod(fd, file.mode))
            end)
            uv.fs_close(fd)
            assert(wrote, why)
            unchanged(file)
            assert(uv.fs_rename(temporary, file.path))
            completed = completed + 1
            for _, ref in ipairs(refs) do
                if vim.api.nvim_buf_is_loaded(ref.buf) then
                    assert(vim.api.nvim_buf_get_changedtick(ref.buf) == ref.tick and not vim.bo[ref.buf].modified,
                        'File replaced; newer buffer edits were kept')
                    vim.api.nvim_buf_call(ref.buf, function() vim.cmd 'silent edit' end)
                end
            end
        end)
        if temporary then uv.fs_unlink(temporary) end
        if not success then callback(tostring(write_error), completed); return end
        vim.schedule(next_file)
    end
    vim.schedule(next_file)
end

return M
