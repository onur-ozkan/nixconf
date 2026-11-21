local M = {}
local files = require 'git_files'
local format = '%H%x00%h%x00%an%x00%as%x00%s%x00'

local function metadata(fields)
    return { hash = fields[1], short = fields[2], author = fields[3], date = fields[4], subject = fields[5] }
end

function M.probe(cwd, callback)
    files.root(cwd, function(root)
        if not root then callback(nil); return end
        files.run(root, { 'log', '--all', '-1', '--format=%H' }, function(out)
            callback(out.code == 0 and out.stdout:find('%x') and root or nil)
        end)
    end)
end

-- NUL-delimited messages are separate ripgrep records. Newlines can match within
-- a message, while patterns cannot accidentally span two different commits.
function M.search(root, query, options, callback)
    local args = { 'rg', '--json', '--null-data', '--passthru', '--color=never',
        options.case and '--case-sensitive' or '--ignore-case' }
    if options.regex or query == '' then table.insert(args, '--engine=auto') else table.insert(args, '--fixed-strings') end
    if options.word and query ~= '' then table.insert(args, '--word-regexp') end
    vim.list_extend(args, { '--regexp', query == '' and '^' or query })
    local git, rg, cancelled, truncated, failure
    local pending, commits, fields, carry, json, index = {}, {}, {}, '', '', 0
    local function stop()
        if git then pcall(git.kill, git, 15) end
        if rg then pcall(rg.kill, rg, 15) end
    end
    local function record(line)
        local event = vim.json.decode(line)
        if event.type ~= 'match' and event.type ~= 'context' then return end
        local data = event.data
        local commit = pending[data.line_number]
        pending[data.line_number] = nil
        if event.type == 'context' or not commit then return end
        if #commits == 2000 then truncated = true; stop(); return end
        commit.matches = data.submatches
        commits[#commits + 1] = commit
    end
    rg = vim.system(args, { stdin = true, stdout = vim.schedule_wrap(function(err, chunk)
        if cancelled or truncated or failure then return end
        if err then failure = tostring(err); stop(); return end
        if not chunk then return end
        json = json .. chunk
        while true do
            local ending = json:find('\n', 1, true)
            if not ending then break end
            local line = json:sub(1, ending - 1)
            json = json:sub(ending + 1)
            local ok, why = pcall(record, line)
            if not ok then failure = tostring(why); stop(); break end
            if truncated then break end
        end
    end) }, vim.schedule_wrap(function(out)
        if cancelled then return end
        if not truncated and out.code > 1 then failure = failure or vim.trim(out.stderr) end
        stop()
        callback({ commits = commits, count = #commits, truncated = truncated, error = failure })
    end))
    git = files.run(root, { 'log', '--all', '-z', '--encoding=UTF-8', '--format=tformat:' .. format .. '%b' }, function(out)
        if cancelled or truncated or failure then return end
        if out.code ~= 0 then failure = vim.trim(out.stderr) end
        pcall(rg.write, rg, nil)
    end, {
        stdout = vim.schedule_wrap(function(err, chunk)
            if cancelled or truncated or failure then return end
            if err then failure = tostring(err); stop(); return end
            if not chunk then return end
            carry = carry .. chunk
            local messages = {}
            while true do
                local ending = carry:find('\0', 1, true)
                if not ending then break end
                fields[#fields + 1] = carry:sub(1, ending - 1)
                carry = carry:sub(ending + 1)
                if #fields == 6 then
                    index = index + 1
                    local commit = metadata(fields)
                    commit.message = fields[5] .. (fields[6] ~= '' and ('\n\n' .. fields[6]) or '')
                    pending[index] = commit
                    local text = options.body ~= false and commit.message or commit.subject
                    messages[#messages + 1] = text .. '\0'
                    fields = {}
                end
            end
            if #messages > 0 then pcall(rg.write, rg, table.concat(messages)) end
        end),
    })
    return function() cancelled = true; stop() end
end

local function parse_log(text, path)
    local tokens, commits, i, current = vim.split(text, '\0', { plain = true }), {}, 1, path
    while i <= #tokens do
        if tokens[i] == '' and (tokens[i + 1] or ''):match('^%x+$') then
            local fields = {}
            for offset = 1, 6 do fields[offset] = tokens[i + offset] or '' end
            local commit = metadata(fields)
            commit.path = current
            commits[#commits + 1] = commit
            i = i + 7
            while i <= #tokens and tokens[i] ~= '' do
                local status = tokens[i]:gsub('^\n', '')
                if status:match('^[RC]%d+$') then
                    local old, new = tokens[i + 1], tokens[i + 2]
                    if new == current then commit.path, commit.previous, current = new, old, old end
                    i = i + 3
                else
                    i = i + 2
                end
            end
        else
            i = i + 1
        end
    end
    return commits
end

function M.file(root, path, callback, directory)
    local args = { 'log', '--find-renames', '-z', '--encoding=UTF-8',
        '--format=tformat:%x00' .. format, '--name-status' }
    if not directory then args[#args + 1] = '--follow' end
    vim.list_extend(args, { '--', path })
    return files.run(root, args, function(out)
        if out.code ~= 0 then
            M.probe(root, function(history)
                callback({ commits = {}, error = history and vim.trim(out.stderr) or nil })
            end)
            return
        end
        callback({ commits = parse_log(out.stdout, path) })
    end)
end

local function unquote(path)
    if path:sub(1, 1) ~= '"' then return path end
    local escapes = { n = '\n', r = '\r', t = '\t', a = '\7', b = '\8', v = '\11', f = '\12', ['\\'] = '\\', ['"'] = '"' }
    local result, i = {}, 2
    while i < #path do
        local char = path:sub(i, i)
        if char == '\\' then
            local octal = path:sub(i + 1, i + 3):match('^[0-7][0-7][0-7]$')
            if octal then char, i = string.char(tonumber(octal, 8)), i + 4
            else char, i = escapes[path:sub(i + 1, i + 1)] or path:sub(i + 1, i + 1), i + 2 end
        else i = i + 1 end
        result[#result + 1] = char
    end
    return table.concat(result)
end

function M.line(root, path, line, contents, callback)
    return files.run(root, { 'blame', '--line-porcelain', '--contents', '-', '-L', line .. ',' .. line, '--', path }, function(out)
        if out.code ~= 0 then
            files.run(root, { 'cat-file', '-e', 'HEAD:' .. path }, function(check)
                callback(nil, check.code ~= 0 and 'Line not committed yet' or vim.trim(out.stderr))
            end)
            return
        end
        local hash = out.stdout:match('^(%x+)')
        if not hash or hash:match('^0+$') then callback(nil, 'Line not committed yet'); return end
        local historical = unquote(out.stdout:match('\nfilename ([^\n]*)') or path)
        files.run(root, { 'show', '-z', '--encoding=UTF-8', '--format=tformat:%x00' .. format,
            '--name-status', '--find-renames', '--first-parent', hash }, function(info)
            if info.code ~= 0 then callback(nil, vim.trim(info.stderr)); return end
            local commit = parse_log(info.stdout, historical)[1]
            callback(commit, not commit and 'Cannot read the line commit' or nil)
        end)
    end, { stdin = contents })
end

function M.diff(root, commit, complete, callback)
    local args = { 'show', '--no-ext-diff', '--no-textconv', '--no-color', '--format=fuller',
        '--stat', '--patch', '--find-renames', '--first-parent', commit.hash }
    if not complete and commit.path then
        vim.list_extend(args, { '--', commit.path })
        if commit.previous then args[#args + 1] = commit.previous end
    end
    return files.run(root, args, function(out)
        callback(out.code == 0 and out.stdout or nil, out.code ~= 0 and vim.trim(out.stderr) or nil)
    end)
end

return M
