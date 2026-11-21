local M = {}
local git = require 'git_history'
local active
local opening = 0
local group = vim.api.nvim_create_augroup('FileHistory', { clear = true })

local function without_equalizing(action)
    local equal = vim.o.equalalways
    vim.o.equalalways = false
    local ok, err = pcall(action)
    vim.o.equalalways = equal
    if not ok then error(err) end
end

local function lines(buf, text)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, '\n', { plain = true }))
    vim.bo[buf].modifiable, vim.bo[buf].modified = false, false
end

local function close(s, focus_origin)
    if s.closing then return end
    s.closing = true
    s.version = s.version + 1
    if s.job then pcall(s.job.kill, s.job, 15) end
    if s.loading then pcall(s.loading.kill, s.loading, 15) end
    local tab, target = s.tab, s.bottom
    local current = vim.api.nvim_get_current_win() == s.top or vim.api.nvim_get_current_win() == s.bottom
    s.tab = nil
    if not vim.api.nvim_win_is_valid(target) and s.top and vim.api.nvim_win_is_valid(s.top) then target = s.top end
    local view, displaced = s.original.view, false
    if vim.api.nvim_win_is_valid(target) then
        local buf = vim.api.nvim_win_get_buf(target)
        if buf == s.diff_buf or buf == s.list_buf then
            if vim.api.nvim_buf_is_valid(s.original.buf) then vim.api.nvim_win_set_buf(target, s.original.buf) end
        else
            displaced = true
            view = vim.api.nvim_win_call(target, vim.fn.winsaveview)
            require('git_review').clear(s.original.buf, target)
        end
        for key, value in pairs(s.original.options) do vim.wo[target][key] = value end
        vim.w[target].history_pane = s.original.pane
    end
    if s.top and s.top ~= target and vim.api.nvim_win_is_valid(s.top) then
        if vim.api.nvim_get_current_win() == s.top then vim.api.nvim_set_current_win(target) end
        without_equalizing(function() vim.api.nvim_win_close(s.top, true) end)
    end
    if vim.api.nvim_win_is_valid(target) then
        vim.api.nvim_win_call(target, function() vim.fn.winrestview(view) end)
    end
    if vim.api.nvim_buf_is_valid(s.original.buf) then vim.bo[s.original.buf].bufhidden = s.original.hidden end
    if vim.api.nvim_tabpage_is_valid(tab) then vim.t[tab].git_view_title = s.original.title end
    if s.created and not displaced and vim.api.nvim_win_is_valid(target) and vim.api.nvim_tabpage_is_valid(tab)
        and #vim.api.nvim_tabpage_list_wins(tab) > 1 then vim.api.nvim_win_close(target, true) end
    if current and focus_origin ~= false then
        if vim.api.nvim_win_is_valid(s.origin) then vim.api.nvim_set_current_win(s.origin)
        elseif vim.api.nvim_win_is_valid(target) then vim.api.nvim_set_current_win(target) end
    end
    if active == s then active = nil end
end

function M.restore(tab)
    opening = opening + 1
    if active and active.tab == tab then close(active, false) end
end

local function preview(s)
    if not s.tab then return end
    s.version = s.version + 1
    local version = s.version
    if s.job then pcall(s.job.kill, s.job, 15); s.job = nil end
    vim.wo[s.top or s.bottom].winbar = '%#Title#[' .. (s.complete and 'x' or ' ') .. '] Complete Diff%*  (Space)  '
        .. vim.fn.strtrans(s.path):gsub('%%', '%%%%')
    local commit = s.commit or s.commits[vim.api.nvim_win_get_cursor(s.top)[1]]
    if not commit then lines(s.diff_buf, 'No commit selected'); return end
    local key = commit.hash .. '\0' .. commit.path .. '\0' .. tostring(s.complete)
    if s.top then
        vim.wo[s.bottom].winbar = '%#Title#' .. commit.short
            .. (s.complete and ' — Complete Diff' or s.directory and ' — Directory Diff' or ' — File Diff')
    end
    if s.cache[key] then lines(s.diff_buf, s.cache[key]); return end
    lines(s.diff_buf, 'Loading diff…')
    vim.defer_fn(function()
        if not s.tab or s.version ~= version or not vim.api.nvim_buf_is_valid(s.diff_buf) then return end
        s.job = git.diff(s.root, commit, s.complete, function(text, err)
            if not s.tab or s.version ~= version or not vim.api.nvim_buf_is_valid(s.diff_buf) then return end
            s.job = nil
            if text then s.cache[key] = text end
            lines(s.diff_buf, text or ('ERROR: ' .. err))
        end)
    end, 40)
end

local function load(s)
    local selected = s.commits[vim.api.nvim_win_get_cursor(s.top)[1]]
    local generation = (s.generation or 0) + 1
    s.generation = generation
    if s.loading then pcall(s.loading.kill, s.loading, 15) end
    s.loading = git.file(s.root, s.path, function(result)
        if not s.tab or s.generation ~= generation or not vim.api.nvim_buf_is_valid(s.list_buf) then return end
        s.loading, s.commits, s.rendering = nil, result.commits, true
        local output, row = {}, 1
        for i, commit in ipairs(s.commits) do
            output[i] = vim.fn.strtrans(string.format('%s  %s  — %s (%s)', commit.short, commit.subject, commit.author, commit.date))
            if selected and commit.hash == selected.hash then row = i end
        end
        lines(s.list_buf, #output > 0 and table.concat(output, '\n') or result.error and ('ERROR: ' .. result.error) or 'No history for this path')
        vim.api.nvim_win_set_cursor(s.top, { row, 0 })
        s.rendering = false
        preview(s)
    end, s.directory)
end

local function show(root, path, origin, commit, directory)
    local tab = vim.api.nvim_get_current_tabpage()
    if active and active.tab == tab and active.root == root and active.path == path
        and (active.commit and active.commit.hash or '') == (commit and commit.hash or '') then
        active.origin = origin
        vim.api.nvim_set_current_tabpage(active.tab)
        vim.api.nvim_set_current_win(active.top or active.bottom)
        if commit then preview(active) else load(active) end
        return
    end
    if active then close(active, false) end
    local editor = require('sidebar_layout').editor(tab, origin)
    local created = not editor
    if not editor then
        vim.cmd 'leftabove vnew'
        editor = vim.api.nvim_get_current_win()
    end
    if not commit and vim.api.nvim_win_get_height(editor) < 6 then
        if created then vim.api.nvim_win_close(editor, true) end
        if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
        vim.api.nvim_echo({ { 'Editor pane is too small for history', 'Comment' } }, false, {})
        return
    end
    local original = { buf = vim.api.nvim_win_get_buf(editor), options = {},
        view = vim.api.nvim_win_call(editor, vim.fn.winsaveview), pane = vim.w[editor].history_pane,
        title = vim.t[tab].git_view_title }
    original.hidden = vim.bo[original.buf].bufhidden
    for _, key in ipairs({ 'number', 'relativenumber', 'signcolumn', 'wrap', 'foldenable', 'spell',
        'cursorline', 'cursorlineopt', 'winhighlight', 'winbar', 'winfixheight', 'winfixwidth' }) do
        original.options[key] = vim.wo[editor][key]
    end
    local s = { root = root, path = path, origin = origin, commits = {}, cache = {}, version = 0,
        complete = false, commit = commit, directory = directory, original = original, created = created,
        tab = tab, bottom = editor, opening = true }
    active = s
    vim.bo[original.buf].bufhidden = 'hide'
    s.diff_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[s.diff_buf].filetype = 'githistory'
    vim.w[editor].history_pane = 'diff'
    vim.api.nvim_set_current_win(editor)
    local height = vim.api.nvim_win_get_height(editor)
    vim.api.nvim_win_set_buf(editor, s.diff_buf)
    local name = path == '.' and vim.fs.basename(root) or vim.fs.basename(path)
    vim.t[s.tab].git_view_title = name .. ':' .. (commit and commit.short or 'history')
    if not commit then
        without_equalizing(function() vim.cmd 'aboveleft new' end)
        s.top, s.list_buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    end
    local wins = { diff = s.bottom }
    if s.top then wins.commits = s.top end
    for pane, win in pairs(wins) do
        local buf = vim.api.nvim_win_get_buf(win)
        vim.w[win].history_pane = pane
        vim.api.nvim_buf_set_name(buf, (pane == 'commits' and 'History: ' or 'History diff: ') .. vim.fn.strtrans(path))
        for key, value in pairs({ buftype = 'nofile', bufhidden = 'wipe', buflisted = false, swapfile = false,
            filetype = 'githistory' }) do vim.bo[buf][key] = value end
        for key, value in pairs({ number = false, relativenumber = false, signcolumn = 'no', wrap = false,
            foldenable = false, cursorline = pane == 'commits', cursorlineopt = 'both',
            winhighlight = 'NormalNC:Normal,WinBar:Normal,WinBarNC:Normal,CursorLine:SidebarSelection' }) do vim.wo[win][key] = value end
        vim.keymap.set('n', '<Esc>', function() close(s) end, { buffer = buf, silent = true })
    end
    vim.bo[s.diff_buf].syntax = 'diff'
    lines(s.diff_buf, '')
    vim.keymap.set('n', '<Space>', function() s.complete = not s.complete; preview(s) end,
        { buffer = s.list_buf or s.diff_buf, silent = true })
    if s.top then
        vim.api.nvim_win_set_height(s.top, math.max(1, math.floor((height - 3) / 3)))
        vim.wo[s.top].winbar = '%#Title#[ ] Complete Diff%*  (Space)  ' .. vim.fn.strtrans(path):gsub('%%', '%%%%')
        lines(s.list_buf, 'Loading history…')
        vim.keymap.set('n', '<CR>', function() vim.api.nvim_set_current_win(s.bottom) end, { buffer = s.list_buf, silent = true })
        vim.api.nvim_create_autocmd('CursorMoved', { group = group, buffer = s.list_buf, callback = function()
            if not s.rendering and vim.api.nvim_get_current_win() == s.top then preview(s) end
        end })
        load(s)
    else
        preview(s)
    end
    s.opening = false
end

function M.open()
    if active and (vim.api.nvim_get_current_win() == active.top or vim.api.nvim_get_current_win() == active.bottom) then
        vim.api.nvim_set_current_win(active.top or active.bottom)
        return active
    end
    opening = opening + 1
    local request = opening
    local origin, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local tree = vim.bo.filetype == 'NvimTree'
    local file, directory, contents, line, tick
    if tree then
        local node = require('nvim-tree.api').tree.get_node_under_cursor()
        if not node or not node.absolute_path then return end
        file, directory = vim.fs.normalize(node.absolute_path), node.type == 'directory'
    else
        file = vim.api.nvim_buf_get_name(buf)
        if vim.bo.buftype ~= '' or file == '' then return end
        file = vim.uv.fs_realpath(file) or file
        line, tick = vim.fn.line('.'), vim.api.nvim_buf_get_changedtick(buf)
        contents = require('git_files').contents(buf)
    end
    local function valid()
        if opening ~= request or not vim.api.nvim_win_is_valid(origin) or vim.api.nvim_get_current_win() ~= origin
            or vim.api.nvim_get_current_buf() ~= buf then return false end
        if tree then
            local node = require('nvim-tree.api').tree.get_node_under_cursor()
            return node and node.absolute_path and vim.fs.normalize(node.absolute_path) == file
        end
        return vim.api.nvim_buf_get_changedtick(buf) == tick and vim.fn.line('.') == line
    end
    require('git_files').root(directory and file or vim.fs.dirname(file), function(root)
        if not valid() then return end
        if not root then vim.api.nvim_echo({ { 'Not inside a Git repository', 'Comment' } }, false, {}); return end
        local path = vim.fs.relpath(root, file)
        if not path or path == '' then path = '.' end
        if tree then show(root, path, origin, nil, directory); return end
        git.line(root, path, line, contents, function(commit, err)
            if not valid() then return end
            if not commit then vim.api.nvim_echo({ { err, 'Comment' } }, true, {}); return end
            show(root, path, origin, commit)
        end)
    end)
end

function M.open_commit(root, commit)
    opening = opening + 1
    local request, origin = opening, vim.api.nvim_get_current_win()
    git.diff(root, commit, true, function(text, err)
        if opening ~= request or not vim.api.nvim_win_is_valid(origin) or vim.api.nvim_get_current_win() ~= origin then return end
        if err then require('git_files').error(err); return end
        local buf = vim.api.nvim_create_buf(false, true)
        vim.bo[buf].filetype, vim.bo[buf].bufhidden = 'gitcommitview', 'wipe'
        vim.bo[buf].syntax = 'diff'
        vim.api.nvim_buf_set_name(buf, 'Commit ' .. commit.short)
        lines(buf, text)
        vim.cmd('tab sbuffer ' .. buf)
        vim.t.git_view_title = 'commit:' .. commit.short
        vim.wo.cursorline = false
        vim.keymap.set('n', '<Esc>', function()
            vim.cmd 'tabclose'
            if vim.api.nvim_win_is_valid(origin) then vim.api.nvim_set_current_win(origin) end
        end, { buffer = buf, silent = true })
    end)
end

vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(event)
    local s = active
    if s and not s.closing and (tonumber(event.match) == s.top or tonumber(event.match) == s.bottom) then
        vim.schedule(function() if active == s then close(s) end end)
    end
end })
vim.api.nvim_create_autocmd('BufWinEnter', { group = group, callback = function()
    local s = active
    if s and not s.closing and not s.opening and vim.api.nvim_get_current_win() == s.bottom
        and vim.api.nvim_get_current_buf() ~= s.diff_buf then close(s, false) end
end })
vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    local s = active
    if not s then return end
    s.closing, s.tab, s.version = true, nil, s.version + 1
    if s.job then pcall(s.job.kill, s.job, 15) end
    if s.loading then pcall(s.loading.kill, s.loading, 15) end
end })

return M
