local M = {}
local git_files = require 'git_files'
local icons = require 'git_icons'
local revert = require 'git_revert'
local layout = require 'sidebar_layout'
local summary = require 'git_summary'
local review = require 'git_review'
local git = git_files.run
local sections = { 'staged', 'unstaged' }
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

local function in_visual_mode()
    local mode = vim.fn.mode():sub(1, 1)
    return mode == 'v' or mode == 'V' or mode == '\22'
end

local function selection_range()
    local first, last = vim.fn.line('.'), vim.fn.line('.')
    if in_visual_mode() then
        first = vim.fn.line('v')
        vim.cmd('normal! ' .. vim.keycode('<Esc>'))
    end
    return math.min(first, last), math.max(first, last)
end

local function selected(panel)
    if not vim.api.nvim_win_is_valid(panel.win) then return end
    return panel.rows[vim.api.nvim_win_get_cursor(panel.win)[1]]
end

local function file_entry(row)
    if row and not row.children then return row end
end

local function path_key(section, path, directory)
    return section .. '\0' .. path .. (directory and '\0' or '')
end

local function row_key(row)
    if row then return path_key(row.section, row.path, row.children) end
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
                local row = panel.row_by_key[row_key(active)]
                if row then
                    vim.api.nvim_buf_set_extmark(panel.buf, selection_namespace, row - 1, 0, {
                        end_row = row, hl_group = 'SidebarSelection', hl_eol = true,
                    })
                end
            end
        end
    end
    require('cfg_nvimtree').review(active)
end

local function folders_first(a, b)
    if (a.children ~= nil) ~= (b.children ~= nil) then return a.children ~= nil end
    if a.sort_name == b.sort_name then return a.name < b.name end
    return a.sort_name < b.sort_name
end

local function parent_path(path)
    return path:match('^(.+)/[^/]+/?$') or ''
end

local function build_trees(changes, collapsed, preferred)
    local trees = { staged = { children = {} }, unstaged = { children = {} } }
    local folders = {}
    local function children(section, path)
        if path == '' then return trees[section].children end
        local key = path_key(section, path, true)
        if folders[key] then return folders[key].children end
        local name = path:match('[^/]+$')
        local node = { section = section, path = path, name = name, sort_name = name:lower(), children = {} }
        folders[key] = node
        table.insert(children(section, parent_path(path)), node)
        return node.children
    end
    local function add(section, change, status)
        local path, name = parent_path(change.path), change.path:match('([^/]+)/?$')
        table.insert(children(section, path), { section = section, status = status, path = change.path,
            old_path = change.old_path, conflict = change.conflict, submodule = change.submodule, rename = status == 'R',
            name = name, sort_name = name:lower() })
        if not preferred or path_key(section, change.path) ~= preferred then return end
        while path ~= '' do
            collapsed[path_key(section, path, true)] = nil
            path = parent_path(path)
        end
    end
    for _, change in ipairs(changes) do
        local x, y = change.x, change.y
        if change.conflict then x, y = ' ', 'U' end
        if x ~= ' ' and x ~= '?' then add('staged', change, x) end
        if y ~= ' ' then add('unstaged', change, y) end
    end
    local function sort(node)
        table.sort(node.children, folders_first)
        node.count = #node.children
        for _, child in ipairs(node.children) do
            if child.children then node.count = node.count + sort(child) - 1 end
        end
        return node.count
    end
    for _, root in pairs(trees) do sort(root) end
    return trees
end

local function set_lines(panel, lines)
    vim.api.nvim_buf_clear_namespace(panel.buf, namespace, 0, -1)
    vim.bo[panel.buf].modifiable = true
    vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, lines)
    vim.bo[panel.buf].modifiable = false
end

local function render(panel, preferred)
    summary.close()
    local cursor = vim.api.nvim_win_get_cursor(panel.win)[1]
    local current = panel.rows[cursor]
    local lines, rows, row_by_key, highlights = {}, {}, {}, {}
    local renderer = panel.renderer
    local arrows = renderer.icons.show.folder_arrow and renderer.icons.glyphs.folder
    local arrow_pad = arrows and renderer.icons.padding.folder_arrow or ''
    local file_pad = arrows and (' ' .. arrow_pad) or ''
    local first_file
    local function highlight(column, text, group)
        if text ~= '' then highlights[#highlights + 1] = { #lines - 1, column, column + #text, group } end
    end
    local function draw(nodes, depth)
        local indent = string.rep(' ', depth * renderer.indent_width)
        for _, node in ipairs(nodes) do
            local key = row_key(node)
            local name = vim.fn.strtrans(node.name)
            local open
            if node.children then
                open = not panel.collapsed[key]
                local arrow = arrows and (open and arrows.arrow_open or arrows.arrow_closed) or ''
                local prefix = indent .. arrow .. arrow_pad
                local count = ' (' .. node.count .. ')'
                lines[#lines + 1] = prefix .. name .. count
                highlight(#indent, arrow, open and 'NvimTreeFolderArrowOpen' or 'NvimTreeFolderArrowClosed')
                highlight(#prefix, name, open and 'NvimTreeOpenedFolderName' or 'NvimTreeFolderName')
                highlight(#prefix + #name, count, 'Comment')
            else
                local prefix = indent .. file_pad .. (icons[node.status] or node.status) .. ' '
                local from = node.rename and node.old_path and ' <- ' .. vim.fn.strtrans(node.old_path) or ''
                lines[#lines + 1] = prefix .. name .. (node.submodule and ' [submodule]' or '') .. from
                if vim.tbl_contains(renderer.special_files, node.name) then
                    highlight(#prefix, name, 'NvimTreeSpecialFile')
                end
                first_file = first_file or #lines
            end
            rows[#lines], row_by_key[key] = node, #lines
            if open then draw(node.children, depth + 1) end
        end
    end
    if panel.submodule_path then
        lines[1] = 'Submodule: ' .. vim.fn.strtrans(panel.submodule_path)
        highlight(0, lines[1], 'NvimTreeRootFolder')
    end
    for _, section in ipairs(sections) do
        local tree = panel.trees[section]
        local title = section == 'staged' and 'Staged Changes' or 'Unstaged Changes'
        lines[#lines + 1] = title .. ' (' .. tree.count .. ')'
        highlight(0, lines[#lines], 'Title')
        if tree.count == 0 then
            lines[#lines + 1] = '  (none)'
        else
            draw(tree.children, 0)
        end
        lines[#lines + 1] = ''
    end
    local target = row_by_key[preferred] or row_by_key[row_key(current)]
    if current and not target then
        local path = parent_path(current.path)
        while path ~= '' and not target do
            target = row_by_key[path_key(current.section, path, true)]
            path = parent_path(path)
        end
    end
    panel.rows, panel.row_by_key = rows, row_by_key
    set_lines(panel, lines)
    for _, mark in ipairs(highlights) do
        vim.api.nvim_buf_set_extmark(panel.buf, namespace, mark[1], mark[2], {
            end_col = mark[3], hl_group = mark[4],
        })
    end
    vim.api.nvim_win_set_cursor(panel.win, { target or (not panel.raw and first_file) or math.min(cursor, #lines), 0 })
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
    local preferred = panel.preferred
    if panel.raw == data.raw and not preferred then return end
    -- Avoid changing the file rows under an active visual selection.
    if vim.api.nvim_get_current_win() == panel.win and in_visual_mode() then return end
    panel.trees = build_trees(data.changes or git_files.changes(data.raw), panel.collapsed, preferred)
    render(panel, preferred)
    panel.raw, panel.preferred = data.raw, nil
end

local function refresh_visible()
    local tab = vim.api.nvim_get_current_tabpage()
    local panel = panels[tab]
    local root = panel and panel.root
    local roots = {}
    if panel and not panel.mutating then roots[root] = true end
    git_files.refresh(roots, function(data)
        if panel and panel.root == root then refresh_panel(panel, data[root]) end
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

local function show_repository(panel, root, path, collapsed, preferred)
    summary.close()
    panel.root, panel.submodule_path, panel.collapsed, panel.preferred = root, path, collapsed, preferred
    panel.raw, panel.error, panel.preview, panel.entering = nil, nil, nil, nil
    panel.rows, panel.row_by_key = {}, {}
    set_lines(panel, { 'Loading Git changes...' })
    schedule_selection()
    refresh_visible()
end

local function enter_submodule(panel, entry)
    if panel.mutating or panel.entering then return end
    local root, key = panel.root, row_key(entry)
    local path = vim.fs.joinpath(root, entry.path)
    local function missing() git_files.error('Submodule is not checked out: ' .. vim.fn.strtrans(entry.path)) end
    local request = {}
    panel.entering = request
    git(path, { 'rev-parse', '--show-toplevel' }, function(output)
        if panels[panel.tab] ~= panel or panel.entering ~= request then return end
        panel.entering = nil
        if panel.mutating or vim.api.nvim_get_current_win() ~= panel.win or row_key(selected(panel)) ~= key then return end
        if output.code ~= 0 or output.stdout:gsub('\n$', '') ~= path then return missing() end
        panel.parents[#panel.parents + 1] = { root = root, path = panel.submodule_path, collapsed = panel.collapsed, key = key }
        local label = panel.submodule_path and panel.submodule_path .. '/' .. entry.path or entry.path
        show_repository(panel, path, label, {})
    end)
end

local function leave_submodule(panel)
    if panel.mutating then return end
    panel.entering = nil
    local parent = table.remove(panel.parents)
    if parent then show_repository(panel, parent.root, parent.path, parent.collapsed, parent.key) end
end

local function open_entry(panel, preview)
    local entry = selected(panel)
    if not entry then return end
    if entry.children then
        if not preview then
            local key = row_key(entry)
            panel.collapsed[key] = not panel.collapsed[key] or nil
            render(panel)
        end
        return
    end
    if entry.submodule then
        if preview then summary.open(panel.root, entry, panel.win) else enter_submodule(panel, entry) end
        return
    end
    if entry.path:sub(-1) == '/' then return end -- Git lists untracked embedded repositories as directories.
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
    local entry = file_entry(selected(panel))
    if not entry or panel.mutating then return end
    if entry.submodule and entry.section == 'unstaged' and entry.status == 'M' and entry.submodule:sub(2, 2) ~= 'C' then
        git_files.error('Open the submodule to stage changes to its files')
        return
    end
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
            panel.preferred = path_key(destination, entry.path)
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
        local entry = file_entry(panel.rows[line])
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
        local tree = require('nvim-tree.api').config.global()
        local panel = {
            tab = tab, root = repository, editor = editor,
            win = vim.api.nvim_get_current_win(), buf = vim.api.nvim_get_current_buf(),
            rows = {}, row_by_key = {}, trees = {}, parents = {}, collapsed = {}, win_options = {}, renderer = tree.renderer,
        }
        panels[tab] = panel
        vim.w[panel.win].sidebar_width = 40
        vim.api.nvim_buf_set_name(panel.buf, 'git-changes://' .. tab .. '/' .. panel.root)
        for key, value in pairs({ buftype = 'nofile', bufhidden = 'wipe', buflisted = false,
            swapfile = false, undolevels = -1, filetype = 'gitstatus' }) do
            vim.bo[panel.buf][key] = value
        end
        for key, value in pairs({ number = tree.view.number, relativenumber = tree.view.relativenumber, wrap = false,
            signcolumn = tree.view.signcolumn, cursorline = true, winfixwidth = true, spell = false,
            foldenable = false, foldcolumn = '0', list = false, cursorlineopt = tree.view.cursorlineopt,
            winhighlight = table.concat({ 'Normal:NvimTreeNormal', 'NormalNC:NvimTreeNormalNC',
                'CursorLine:NvimTreeCursorLine', 'LineNr:NvimTreeLineNr', 'CursorLineNr:NvimTreeCursorLineNr',
                'SignColumn:NvimTreeSignColumn', 'EndOfBuffer:NvimTreeEndOfBuffer', 'WinSeparator:NvimTreeWinSeparator',
            }, ',') }) do
            panel.win_options[key] = vim.wo[panel.win][key]
            vim.wo[panel.win][key] = value
        end
        set_lines(panel, { 'Loading Git changes...' })
        layout.finish(tab)
        vim.keymap.set('n', '<Esc>', function() close_panel(panel) end,
            { buffer = panel.buf, silent = true, desc = 'Close Git sidebar' })
        for _, key in ipairs({ '<CR>', '<2-LeftMouse>' }) do
            vim.keymap.set('n', key, function() open_entry(panel) end,
                { buffer = panel.buf, silent = true, desc = 'Toggle folder / enter submodule / open inline diff' })
        end
        vim.keymap.set('n', '-', function() leave_submodule(panel) end,
            { buffer = panel.buf, silent = true, desc = 'Return to parent repository' })
        vim.keymap.set('n', '<C-p>', function() open_entry(panel, true) end,
            { buffer = panel.buf, silent = true, desc = 'Preview inline diff' })
        vim.keymap.set('n', '<Tab>', function()
            local entry = file_entry(selected(panel))
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
