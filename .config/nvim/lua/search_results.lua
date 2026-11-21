local M = {}
local limit = 4000

local function text_lines(text)
    local lines = vim.split(text, '\n', { plain = true })
    if lines[#lines] == '' and #lines > 1 then table.remove(lines) end
    return lines
end

local function commits(s, add, full)
    for _, commit in ipairs(s.result.commits) do
        if full() then break end
        local location = { commit = commit }
        add(vim.fn.strtrans(commit.short .. '  ' .. commit.subject), location, 'Title')
        if s.options.extended then
            add(vim.fn.strtrans('  ' .. commit.author .. ' (' .. commit.date .. ')'), location, 'Comment')
            if commit.message:find('\n', 1, true) then
                local text = vim.split(commit.message, '\n', { plain = true })
                local match = commit.matches[1]
                local _, before = commit.message:sub(1, match and match.start or 0):gsub('\n', '')
                local start = math.max(3, before + 1)
                for i = start, math.min(#text, start + 2) do
                    if text[i] ~= '' then add('  ' .. vim.fn.strtrans(text[i]), location) end
                end
            end
            add('')
        end
    end
    if s.result.count == 0 then add('No matching commits', nil, 'Comment') end
    if s.result.truncated or full() then add('Results shortened; narrow the search', nil, 'Comment') end
    return 'Results — ' .. s.result.count .. ' commits'
end

local function files(s, add, full)
    for _, file in ipairs(s.result.files) do
        if full() then break end
        add(vim.fn.strtrans(file.name) .. ' (' .. file.count .. ')',
            { path = file.path, line = file.changes[1].line, column = file.changes[1].column }, 'Title')
        for _, fragment in ipairs(file.fragments) do
            if full() then break end
            for offset, line in ipairs(text_lines(fragment.text)) do
                if full() then break end
                add(string.format('%s%5d  %s', s.options.replace and '-' or ' ', fragment.line + offset - 1,
                    vim.fn.strcharpart(line:gsub('\r$', ''), 0, 1000)),
                    { path = file.path, line = fragment.line + offset - 1, column = 0 },
                    s.options.replace and 'DiffDelete' or nil)
            end
            if s.options.replace and not full() then
                for _, line in ipairs(text_lines(require('search_engine').apply_text(fragment.text, fragment.changes))) do
                    if full() then break end
                    add('+       ' .. vim.fn.strcharpart(line:gsub('\r$', ''), 0, 1000),
                        { path = file.path, line = fragment.line, column = 0 }, 'DiffAdd')
                end
            end
        end
        add('')
    end
    if s.result.count == 0 then add('No matches', nil, 'Comment') end
    if full() then add('Preview shortened', nil, 'Comment') end
    if s.result.truncated then add('Too many matches; narrow the search before replacing all', nil, 'Comment') end
    return string.format('Results — %d matches in %d files', s.result.count, #s.result.files)
end

-- Produce text, locations, and highlighting without touching editor state.
function M.render(s)
    local output, rows, highlights, title = {}, {}, {}, 'Results'
    local function add(text, location, highlight)
        for _, line in ipairs(vim.split(text, '\n', { plain = true })) do
            output[#output + 1] = line
            rows[#output] = location
            if highlight then highlights[#highlights + 1] = { #output - 1, highlight } end
        end
    end
    local function full() return #output >= limit end
    if s.notice then add(s.notice, nil, s.error and 'GitError' or 'Comment') end
    if s.status ~= 'done' then
        add(s.message or 'Type a search', nil, s.status == 'error' and 'GitError' or 'Comment')
    else
        title = (s.mode == 'commits' and commits or files)(s, add, full)
    end
    return output, rows, highlights, title
end

return M
