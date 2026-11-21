local M = {}
local git_files = require 'git_files'
local icons = require 'git_icons'
local revert = require 'git_revert'
local layout = require 'sidebar_layout'
local summary = require 'git_summary'
local review = require 'git_review'
local git = git_files.run
local panels, opening = {}, {}
local namespace = vim.api.nvim_create_namespace('GitChanges')
local selection_namespace = vim.api.nvim_create_namespace('GitSelection')
local group = vim.api.nvim_create_augroup('GitChanges', { clear = true })
local timer, refresh_scheduled
local update_selection, selection_pending
local function schedule_selection()
    if selection_pending then return end
    selection_pending = true
    vim.schedule(function() selection_pending = false; update_selection() end)
end
local function notify(output)
    git_files.error('Git: ' .. vim.trim(output.stderr))
end

local function selection_range()
    local first, last = vim.fn.line('.'), vim.fn.line('.')
    local mode = vim.fn.mode():sub(1, 1)
    if mode == 'v' or mode == 'V' or mode == '\22' then
        first = vim.fn.line('v')
        vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    end
    return math.min(first, last), math.max(first, last)
end

local function selected(panel)
    if not vim.api.nvim_win_is_valid(panel.win) then return end
    return panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
end

local function entry_key(entry)
    return entry and (entry.section .. '\0' .. entry.path)
end

update_selection = function()
    local win, tab = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_tabpage()
    local panel = panels[tab]
    local active = review.current() or (panel and panel.win == win and panel.preview)
    if not review.valid(active) then active = nil end
    for owner, panel in pairs(panels) do
        if vim.api.nvim_win_is_valid(panel.win) and vim.api.nvim_buf_is_valid(panel.buf) then
            vim.wo[panel.win].cursorline = panel.win == win
            vim.api.nvim_buf_clear_namespace(panel.buf, selection_namespace, 0, -1)
            if owner == tab and panel.win ~= win and active and panel.root == active.root then
                for row, entry in pairs(panel.rows) do
                    if entry_key(entry) == entry_key(active) then
                        vim.api.nvim_buf_set_extmark(panel.buf, selection_namespace, row - 1, 0, {
                            end_row = row, hl_group = 'SidebarSelection', hl_eol = true,
                        })
                        break
                    end
                end
            end
        end
    end
    require('cfg_nvimtree').review(active)
end

local function parse_status(text)
    local sections = { staged = {}, unstaged = {} }
    for _, change in ipairs(git_files.changes(text)) do
        local x, y, path = change.x, change.y, change.path
        local function add(section, status)
            table.insert(sections[section], {
                section = section, status = status, path = path,
                old_path = change.old_path, conflict = change.conflict,
                rename = (section == 'staged' and x == 'R') or (section == 'unstaged' and y == 'R'),
            })
        end
        if change.conflict then
            add('unstaged', 'U')
        elseif x == '?' then
            add('unstaged', '?')
        else
            if x ~= ' ' then add('staged', x) end
            if y ~= ' ' then add('unstaged', y) end
        end
    end
    return sections
end

local function render(panel, sections)
    summary.close()
    local cursor = vim.api.nvim_win_get_cursor(panel.win)[1]
    local keep = panel.preferred or entry_key(selected(panel))
    local lines, rows, headers = {}, {}, {}
    local target
    for _, section in ipairs({ 'staged', 'unstaged' }) do
        local entries = sections[section]
        local title = section == 'staged' and 'Staged Changes' or 'Unstaged Changes'
        table.insert(lines, title .. ' (' .. #entries .. ')')
        table.insert(headers, #lines)
        if #entries == 0 then table.insert(lines, '  (none)') end
        for _, entry in ipairs(entries) do
            local label = vim.fn.strtrans(entry.path)
            if entry.rename then label = vim.fn.strtrans(entry.old_path) .. ' -> ' .. label end
            table.insert(lines, ' ' .. (icons[entry.status] or entry.status) .. ' ' .. label)
            rows[#lines] = entry
            if entry_key(entry) == keep then target = #lines end
        end
        table.insert(lines, '')
    end
    panel.rows, panel.preferred = rows, nil
    vim.bo[panel.buf].modifiable = true
    vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
    vim.bo[panel.buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(panel.buf, namespace, 0, -1)
    for _, line in ipairs(headers) do
        vim.api.nvim_buf_set_extmark(panel.buf, namespace, line - 1, 0, {
            end_col = #lines[line], hl_group = 'Title',
        })
    end
    if not keep then
        for line = 1, #lines do
            if rows[line] then target = line; break end
        end
    end
    vim.api.nvim_win_set_cursor(panel.win, { target or math.min(cursor, #lines), 0 })
    schedule_selection()
end

local function refresh_panel(panel, data)
    if panels[panel.tab] ~= panel or panel.mutating or not data or not data.full then return end
    if data.error then
        if panel.error ~= data.error.stderr then notify(data.error) end
        panel.error = data.error.stderr
        return
    end
    panel.error = nil
    if panel.raw ~= data.raw or panel.preferred then
        render(panel, parse_status(data.raw))
        panel.raw = data.raw
    end
end

local function refresh_visible()
    local tab = vim.api.nvim_get_current_tabpage()
    local panel = panels[tab]
    local roots = {}
    if panel and not panel.mutating then roots[panel.root] = true end
    git_files.refresh(roots, function(data)
        if panel then refresh_panel(panel, data[panel.root]) end
    end)
    review.refresh()
end

local function schedule_refresh()
    if refresh_scheduled then return end
    refresh_scheduled = true
    vim.defer_fn(function()
        refresh_scheduled = false
        refresh_visible()
    end, 100)
end

local function open_entry(panel, preview)
    local entry = selected(panel)
    if not entry then return end
    summary.close()
    require('cfg_history').restore(panel.tab)
    local win = layout.editor(panel.tab, panel.editor)
    if not win then
        vim.api.nvim_set_current_win(panel.win)
        vim.cmd 'rightbelow vnew'
        win = vim.api.nvim_get_current_win()
    end
    panel.editor = win
    panel.preview = review.open(panel.root, entry, win)
    if preview and vim.api.nvim_win_is_valid(panel.win) then vim.api.nvim_set_current_win(panel.win) end
    schedule_selection()
end

local function toggle_stage(panel)
    local entry = selected(panel)
    if not entry or panel.mutating then return end
    summary.close()
    panel.mutating = true
    git_files.invalidate(panel.root)
    local args = entry.section == 'staged' and { 'reset', '--quiet', '--' } or { 'add', '--' }
    table.insert(args, entry.path)
    if entry.rename then table.insert(args, entry.old_path) end
    git(panel.root, args, function(output)
        panel.mutating = false
        git_files.invalidate(panel.root)
        if output.code ~= 0 then
            notify(output)
        else
            local destination = entry.section == 'staged' and 'unstaged' or 'staged'
            panel.preferred = destination .. '\0' .. entry.path
        end
        refresh_visible()
    end)
end

local function revert_files(panel)
    if panel.mutating then return end
    summary.close()
    local first, last = selection_range()
    local entries, seen = {}, {}
    for line = first, last do
        local entry = panel.rows[line]
        if entry then
            if entry.section == 'staged' then
                git_files.error('Cannot revert staged changes')
                return
            end
            if not seen[entry.path] then table.insert(entries, entry); seen[entry.path] = true end
        end
    end
    if #entries == 0 then return end
    panel.mutating = true
    git_files.invalidate(panel.root)
    revert.files(panel.root, entries, function(err)
        panel.mutating = false
        git_files.invalidate(panel.root)
        if err then git_files.error(err) end
        refresh_visible()
    end, function() return panels[panel.tab] == panel and vim.api.nvim_win_is_valid(panel.win) end)
end

local function close_panel(panel)
    summary.close()
    layout.prepare(panel.tab)
    panels[panel.tab] = nil
    local focused = vim.api.nvim_get_current_win() == panel.win
    if #vim.api.nvim_tabpage_list_wins(panel.tab) == 1 then
        -- Keep Backspace usable even after :q closed the last editor window.
        vim.api.nvim_win_set_buf(panel.win, vim.api.nvim_create_buf(true, false))
        for key, value in pairs(panel.win_options) do vim.wo[panel.win][key] = value end
    else
        vim.api.nvim_win_close(panel.win, true)
        local win = layout.editor(panel.tab, panel.editor)
        if focused and win then vim.api.nvim_set_current_win(win) end
    end
    layout.finish(panel.tab)
end

function M.toggle()
    local tab = vim.api.nvim_get_current_tabpage()
    if panels[tab] and vim.api.nvim_win_is_valid(panels[tab].win) then
        close_panel(panels[tab])
        return
    end
    if opening[tab] then opening[tab] = nil; return end
    local request = {}
    opening[tab] = request
    local editor = layout.editor(tab, vim.api.nvim_get_current_win())
    local path = vim.api.nvim_buf_get_name(0)
    local root = vim.fn.getcwd()
    if layout.is_editor(vim.api.nvim_get_current_win()) and path ~= '' then
        root = git_files.directory(path)
    end
    git_files.root(root, function(repository, err)
        if opening[tab] ~= request then return end
        opening[tab] = nil
        if err then notify(err); return end
        if not repository then
            vim.api.nvim_echo({ { 'Not inside a Git repository', 'Comment' } }, false, {})
            return
        end
        if vim.api.nvim_get_current_tabpage() ~= tab then return end
        local anchor = layout.prepare(tab, 'gitstatus', editor)
        if anchor then vim.api.nvim_set_current_win(anchor) end
        vim.cmd('topleft ' .. layout.width('gitstatus') .. 'vnew')
        local panel = {
            tab = tab, root = repository, editor = editor,
            win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf(),
            rows = {}, win_options = {},
        }
        panels[tab] = panel
        vim.w[panel.win].sidebar_width = 40
        vim.api.nvim_buf_set_name(panel.buf, 'git-changes://' .. tab .. '/' .. panel.root)
        for key, value in pairs({ buftype = 'nofile', bufhidden = 'wipe', buflisted = false,
            swapfile = false, filetype = 'gitstatus' }) do
            vim.bo[panel.buf][key] = value
        end
        for key, value in pairs({ number = false, relativenumber = false, wrap = false,
            signcolumn = 'no', cursorline = true, winfixwidth = true, spell = false,
            foldenable = false, cursorlineopt = 'both',
            winhighlight = 'Normal:NvimTreeNormal,NormalNC:NvimTreeNormal,CursorLine:SidebarSelection' }) do
            panel.win_options[key] = vim.wo[panel.win][key]
            vim.wo[panel.win][key] = value
        end
        vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, { 'Loading Git changes...' })
        vim.bo[panel.buf].modifiable = false
        layout.finish(tab)
        vim.keymap.set('n', '<Esc>', function() close_panel(panel) end,
            { buffer = panel.buf, silent = true, desc = 'Close Git sidebar' })
        vim.keymap.set('n', '<CR>', function() open_entry(panel) end,
            { buffer = panel.buf, silent = true, desc = 'Edit file with live inline diff' })
        vim.keymap.set('n', '<C-p>', function() open_entry(panel, true) end,
            { buffer = panel.buf, silent = true, desc = 'Preview inline diff' })
        vim.keymap.set('n', '<Tab>', function()
            local entry = selected(panel)
            if entry then summary.open(panel.root, entry, panel.win) end
        end, { buffer = panel.buf, silent = true, desc = 'Diff summary (Tab / Ctrl+i)' })
        vim.keymap.set('n', '<Space>', function() toggle_stage(panel) end,
            { buffer = panel.buf, silent = true, desc = 'Stage / unstage file' })
        vim.keymap.set({ 'n', 'x' }, 'X', function() revert_files(panel) end,
            { buffer = panel.buf, silent = true, desc = 'Revert current / selected files' })
        refresh_visible()
    end)
end

vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWritePost', 'BufFilePost', 'DirChanged', 'FocusGained', 'TabEnter', 'WinEnter' }, {
    group = group,
    callback = schedule_refresh,
})

vim.api.nvim_create_autocmd({ 'WinEnter', 'BufEnter', 'TabEnter', 'ColorScheme' }, { group = group, callback = schedule_selection })
vim.api.nvim_create_autocmd('User', { group = group, pattern = 'GitReviewChanged', callback = schedule_selection })

vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(event)
        for tab, panel in pairs(panels) do
            if panel.win == tonumber(event.match) then panels[tab] = nil end
        end
    end,
})

vim.api.nvim_create_autocmd('BufWipeout', {
    group = group,
    callback = function(event)
        for tab, panel in pairs(panels) do
            if panel.buf == event.buf then panels[tab] = nil end
        end
    end,
})

vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
        if timer then timer:stop(); timer:close(); timer = nil end
    end,
})

-- Refresh visible UI, including external Git/worktree changes.
timer = vim.uv.new_timer()
timer:start(1500, 1500, vim.schedule_wrap(refresh_visible))
schedule_refresh()

return M
