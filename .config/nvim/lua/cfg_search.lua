local M = {}
local engine = require 'search_engine'
local history = require 'git_history'
local views, serial, exiting, active = {}, 0, false, nil
local group = vim.api.nvim_create_augroup('ProjectSearch', { clear = true })
local ns = vim.api.nvim_create_namespace('ProjectSearch')
local input_ns = vim.api.nvim_create_namespace('ProjectSearchInputs')
local control_ns = vim.api.nvim_create_namespace('ProjectSearchControls')
local controls = { { 'replace', 'Replace' }, { 'case', 'Match case' }, { 'word', 'Whole word' },
    { 'regex', 'Regex' }, { 'filters', 'Filters' } }
local commit_controls = { { 'extended', 'Extended View' }, { 'body', 'Include Body' }, { 'case', 'Match case' },
    { 'word', 'Whole word' }, { 'regex', 'Regex' } }
local labels = { query = 'Search', replacement = 'Replace with', include = 'Include files', exclude = 'Exclude files' }
local placeholders = { query = 'Type to search · Enter adds a line', replacement = 'Replacement text · Enter adds a line',
    include = 'e.g. src/** or *.lua', exclude = 'e.g. **/generated/** or *.lock' }
local hints = { query = 'Enter: newline', replacement = 'Enter: newline',
    include = 'One pattern per line · Empty: all files', exclude = 'One pattern per line',
    results = 'j/k: lines/sections · Enter: open match · Esc: close' }
local request, layout, close, replace_all, change_mode
local action_row = 3

local function replacing(s) return s.mode == 'files' and s.options.replace end

local function remember(s, mode)
    if s.closing or s.layouting or s.opening or s.tab ~= vim.api.nvim_get_current_tabpage() then return end
    if s.wins[vim.b.project_search_field] ~= vim.api.nvim_get_current_win() then return end
    local saved = { views = {}, heights = {}, lines = vim.o.lines, columns = vim.o.columns,
        mode = mode or (vim.fn.mode():match('^i') and 'i' or 'n') }
    for key, win in pairs(s.wins) do
        if vim.api.nvim_win_is_valid(win) then
            saved.views[key] = vim.api.nvim_win_call(win, vim.fn.winsaveview)
            saved.heights[key] = vim.api.nvim_win_get_height(win)
            if win == vim.api.nvim_get_current_win() then saved.focus = key end
            if labels[key] then vim.bo[s.bufs[key]].modified = false end
        end
    end
    local insertion = mode == 'i' and s.insert_view
    if insertion and insertion.key == saved.focus then saved.views[saved.focus] = vim.deepcopy(insertion.view) end
    s.saved = saved
end

local function resize(s)
    local fields, control_height = #s.order - 3, replacing(s) and action_row or 1
    -- Reserve headings, dividers, screen chrome, and four lines of results.
    local spare = math.max(0, vim.o.lines - 3 * fields - control_height - 11)
    for _, key in ipairs(s.order) do
        if labels[key] then
            local extra = math.min(5, #vim.split(s.values[key], '\n', { plain = true }) - 1, spare)
            vim.api.nvim_win_set_height(s.wins[key], 1 + extra)
            spare = spare - extra
            vim.bo[s.bufs[key]].modifiable = not s.applying
        end
    end
    vim.api.nvim_win_set_height(s.wins.controls, control_height)
    vim.api.nvim_win_set_height(s.wins.modes, 1)
end

local function button_index(s)
    local cursor = vim.api.nvim_win_get_cursor(s.wins.controls)
    local index = 1
    for i, button in ipairs(s.buttons or {}) do if cursor[2] >= button.first then index = i end end
    return index
end

local function update_focus(s)
    local buf = s.bufs.controls
    if s.tab ~= vim.api.nvim_get_current_tabpage() or not buf or not vim.api.nvim_buf_is_valid(buf) then return end
    vim.api.nvim_buf_clear_namespace(buf, control_ns, 0, -1)
    local key, hint = vim.b.project_search_field
    if key == 'controls' and s.buttons then
        local row = vim.fn.line('.')
        if row ~= 1 and row ~= action_row then return end
        if row == 1 then s.control = button_index(s) end
        local button = s.buttons[s.control or 1]
        if row == 1 and vim.fn.col('.') - 1 ~= button.first then vim.api.nvim_win_set_cursor(0, { 1, button.first }) end
        vim.api.nvim_buf_set_extmark(buf, control_ns, row - 1, row == 1 and button.first or 0, {
            end_col = row == 1 and button.last or #vim.api.nvim_get_current_line(), hl_group = 'Visual',
        })
        hint = row == 1 and 'h/l: toggles · j/k: sections · Space: toggle · Esc: close'
            or 'j/k: sections · Space/Enter: replace all · Esc: close'
    elseif key == 'modes' then
        hint = 'h/l: search mode · Ctrl+j/k: sections · Esc: close'
    elseif hints[key] then
        hint = labels[key] and (vim.fn.mode():match('^i') and (hints[key] .. ' · Esc: normal')
            or 'hjkl: move · j/k at edges: sections · i: edit · Esc: close') or hints[key]
    end
    if not hint then return end
    vim.b.project_search_hint = hint
    require('lualine').refresh({ place = { 'statusline' }, scope = 'window', force = true })
end

local function focus(s, key, row, edit)
    vim.cmd 'stopinsert'
    vim.api.nvim_set_current_win(s.wins[key])
    if key == 'controls' then
        vim.api.nvim_win_set_cursor(0, { row or 1, row == action_row and 0 or s.buttons[s.control or 1].first })
        update_focus(s)
    end
    resize(s)
    if edit ~= false and labels[key] and not s.applying then
        local cursor = s.cursors[key]
        if cursor then vim.api.nvim_win_set_cursor(0, cursor) end
        local at_end = cursor and cursor[2] == #vim.api.nvim_get_current_line()
        vim.cmd(at_end and 'startinsert!' or 'startinsert')
    end
end

local function move(s, delta, edit)
    local win = vim.api.nvim_get_current_win()
    for i, key in ipairs(s.order) do
        if s.wins[key] == win then
            local row = key == 'controls' and vim.fn.line('.') or 0
            if replacing(s) and key == 'controls' and (row < action_row and delta == 1 or row > 1 and delta == -1) then
                focus(s, key, delta == 1 and action_row or 1, edit)
            else
                local next_key = s.order[i + delta]
                if next_key then
                    focus(s, next_key, next_key == 'controls' and delta == -1 and replacing(s) and action_row or 1, edit)
                end
            end
            return
        end
    end
end

local function normal_move(s, key, delta)
    local name, cursor = vim.b.project_search_field, vim.api.nvim_win_get_cursor(0)
    local last = vim.api.nvim_buf_line_count(0)
    if name ~= 'controls' and name ~= 'modes' and (delta < 0 and cursor[1] > 1 or delta > 0 and cursor[1] < last) then
        vim.cmd('normal! ' .. vim.v.count1 .. key)
        return
    end
    move(s, delta, false)
    local next_name = vim.b.project_search_field
    if next_name ~= name and next_name ~= 'controls' and next_name ~= 'modes' then
        local row = delta > 0 and 1 or vim.api.nvim_buf_line_count(0)
        local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1]
        vim.api.nvim_win_set_cursor(0, { row, math.min(cursor[2], math.max(0, #line - 1)) })
    end
end

local function set_lines(buf, text)
    if vim.deep_equal(vim.api.nvim_buf_get_lines(buf, 0, -1, false), text) then return end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
    vim.bo[buf].modified, vim.bo[buf].modifiable = false, false
end

local function render(s)
    if not s.tab or not vim.api.nvim_tabpage_is_valid(s.tab)
        or not vim.api.nvim_win_is_valid(s.wins.results) or not vim.api.nvim_win_is_valid(s.wins.controls) then return end
    local modes = s.project.root and ' In files   In Commits' or ' In files'
    set_lines(s.bufs.modes, { modes })
    vim.api.nvim_buf_clear_namespace(s.bufs.modes, control_ns, 0, -1)
    local first, last = s.mode == 'files' and 0 or 12, s.mode == 'files' and 9 or #modes
    vim.api.nvim_buf_set_extmark(s.bufs.modes, control_ns, 0, first, { end_col = last, hl_group = 'Visual' })
    vim.api.nvim_win_set_cursor(s.wins.modes, { 1, first })
    local parts, column = {}, 0
    local cursor = vim.api.nvim_win_get_cursor(s.wins.controls)
    local selected = button_index(s)
    s.buttons = {}
    for _, option in ipairs(s.mode == 'commits' and commit_controls or controls) do
        local label = option[2]
        if option[1] == 'filters' and s.options.filters then
            local count = 0
            for pattern in (s.values.include .. '\n' .. s.values.exclude):gmatch('[^\n]+') do
                if vim.trim(pattern) ~= '' then count = count + 1 end
            end
            if count > 0 then label = label .. ' (' .. count .. ')' end
        end
        local text = '[' .. (s.options[option[1]] and 'x' or ' ') .. '] ' .. label
        s.buttons[#s.buttons + 1] = { key = option[1], first = column, last = column + #text }
        parts[#parts + 1], column = text, column + #text + 2
    end
    local bar = { table.concat(parts, '  ') }
    if replacing(s) then bar[2], bar[action_row] = '', s.applying and '[Replacing…]' or '[Replace all]' end
    set_lines(s.bufs.controls, bar)
    local row = math.min(cursor[1], #bar)
    vim.api.nvim_win_set_cursor(s.wins.controls, { row, row == 1 and s.buttons[selected].first or 0 })
    for key in pairs(labels) do
        local buf = s.bufs[key]
        if buf and vim.api.nvim_buf_is_valid(buf) then
            vim.api.nvim_buf_clear_namespace(buf, input_ns, 0, -1)
            if s.values[key] == '' then
                vim.api.nvim_buf_set_extmark(buf, input_ns, 0, 0, {
                    virt_text = { { placeholders[key], 'Comment' } }, virt_text_pos = 'overlay',
                })
            end
        end
    end
    local output, rows, highlights, title = require('search_results').render(s)
    s.rows = rows
    set_lines(s.bufs.results, output)
    vim.api.nvim_buf_clear_namespace(s.bufs.results, ns, 0, -1)
    for _, highlight in ipairs(highlights) do
        vim.api.nvim_buf_set_extmark(s.bufs.results, ns, highlight[1], 0, {
            end_row = highlight[1] + 1, hl_group = highlight[2], hl_eol = true,
        })
    end
    vim.wo[s.wins.results].winbar = '%#Title#' .. title
    update_focus(s)
end

local function stop(s)
    s.version = s.version + 1
    if s.cancel then s.cancel(); s.cancel = nil end
end

request = function(s, delay, keep_notice)
    stop(s)
    if not keep_notice then s.notice, s.error = nil, nil end
    s.status, s.message = 'searching', 'Searching…'
    local version = s.version
    render(s)
    vim.defer_fn(function()
        if s.version ~= version or not s.tab then return end
        if s.values.query == '' and s.mode == 'files' then s.status, s.message = 'empty', 'Type a search'; render(s); return end
        local function done(result)
            if s.version ~= version or not s.tab then return end
            s.cancel, s.result = nil, result
            s.status, s.message = result.error and 'error' or 'done', result.error and ('ERROR: ' .. result.error) or nil
            s.result_version = version
            render(s)
        end
        if s.mode == 'commits' then
            s.cancel = history.search(s.project.root, s.values.query, vim.deepcopy(s.options), done)
        else
            s.cancel = engine.search(s.cwd, vim.deepcopy(s.values), vim.deepcopy(s.options), done)
        end
    end, delay or 0)
end

replace_all = function(s)
    if s.mode ~= 'files' then return end
    if s.applying then return end
    if s.status ~= 'done' or s.result_version ~= s.version or s.result.truncated then
        s.notice, s.error = 'ERROR: Finish or narrow the search before replacing all', true
        render(s)
        return
    end
    if s.result.count == 0 then return end
    s.applying = true
    local version = s.version
    layout(s)
    engine.replace(s.result.files, function() return s.tab ~= nil and s.version == version end, function(err, count)
        s.applying = false
        for key in pairs(labels) do
            local buf = s.bufs[key]
            if buf and vim.api.nvim_buf_is_valid(buf) then vim.bo[buf].modifiable = true end
        end
        if not s.tab or s.version ~= version then layout(s); return end
        s.notice, s.error = err and ('ERROR: ' .. err:gsub('^.-%.lua:%d+: ', '')) or ('Replaced matches in ' .. count .. ' files'), err ~= nil
        if err and count > 0 then s.notice = s.notice .. ' (' .. count .. ' files already replaced)' end
        require('git_files').invalidate(s.cwd)
        request(s, 0, true)
        layout(s)
    end)
end

local function origin(s)
    if vim.api.nvim_tabpage_is_valid(s.origin_tab) then vim.api.nvim_set_current_tabpage(s.origin_tab) else vim.cmd 'tabnew' end
    require('cfg_history').restore(vim.api.nvim_get_current_tabpage())
    local win = require('sidebar_layout').editor(nil, s.origin_win)
    if win then vim.api.nvim_set_current_win(win); return end
    vim.cmd 'vnew'
end

local function goto_result(s)
    if s.status ~= 'done' or s.result_version ~= s.version then return end
    local location = s.rows[vim.fn.line('.')]
    if not location then return end
    if location.commit then require('cfg_history').open_commit(s.project.root, location.commit); return end
    require('git_review').normal_open(function()
        origin(s)
        local buf = vim.fn.bufadd(location.path)
        vim.fn.bufload(buf)
        vim.bo[buf].buflisted = true
        vim.api.nvim_win_set_buf(0, buf)
        vim.api.nvim_win_set_cursor(0, { location.line, location.column })
    end)
end

local function selector_maps(buf, state, select)
    local opts = { buffer = buf, silent = true }
    for key, delta in pairs({ h = -1, b = -1, B = -1, ge = -1, gE = -1,
        l = 1, w = 1, W = 1, e = 1, E = 1, ['<C-h>'] = -1, ['<C-l>'] = 1 }) do
        vim.keymap.set('n', key, function()
            local count, index = state()
            select(math.max(1, math.min(count, index + delta * vim.v.count1)))
        end, opts)
    end
    for key, last in pairs({ ['0'] = false, ['^'] = false, ['$'] = true }) do
        vim.keymap.set('n', key, function() select(last and state() or 1) end, opts)
    end
end

local function new_buffer(s, name, value)
    local buf = vim.api.nvim_create_buf(false, true)
    s.bufs[name] = buf
    vim.api.nvim_buf_set_name(buf, 'Search ' .. s.id .. ' ' .. (labels[name] or name))
    vim.bo[buf].filetype, vim.bo[buf].bufhidden = 'projectsearch', 'hide'
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(value or '', '\n', { plain = true }))
    vim.bo[buf].modified = false
    vim.b[buf].project_search_field = name
    vim.b[buf].project_search_hint = hints[name]
    if labels[name] then
        vim.bo[buf].autoindent, vim.bo[buf].smartindent, vim.bo[buf].formatoptions = false, false, ''
        vim.api.nvim_create_autocmd('InsertLeavePre', { group = group, buffer = buf, callback = function()
            s.cursors[name] = vim.api.nvim_win_get_cursor(0)
            s.insert_view = { key = name, view = vim.fn.winsaveview() }
        end })
        vim.api.nvim_buf_attach(buf, false, { on_lines = function()
            s.cursors[name] = nil
            s.values[name] = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n')
            stop(s)
            vim.schedule(function()
                if not s.tab or not vim.api.nvim_buf_is_valid(buf) then return end
                vim.bo[buf].modified = false
                request(s, 200)
                layout(s)
            end)
        end })
    else
        vim.bo[buf].modifiable = false
    end
    for key, delta in pairs({ ['<C-k>'] = -1, ['<C-j>'] = 1 }) do
        vim.keymap.set('n', key, function() move(s, delta, false) end, { buffer = buf, silent = true })
    end
    for key, delta in pairs({ j = 1, k = -1 }) do
        vim.keymap.set('n', key, function() normal_move(s, key, delta) end, { buffer = buf, silent = true })
    end
    vim.keymap.set('n', '<Esc>', function() close(s) end, { buffer = buf, silent = true, desc = 'Close Search' })
    if name == 'modes' or name == 'controls' then
        selector_maps(buf, function()
            if name == 'modes' then return s.project.root and 2 or 1, s.mode == 'files' and 1 or 2 end
            return #s.buttons, button_index(s)
        end, function(index)
            if name == 'modes' then
                if s.applying then return end
                vim.api.nvim_win_set_cursor(0, { 1, index == 1 and 0 or 12 })
                change_mode(s, index == 1 and 'files' or 'commits')
            elseif vim.fn.line('.') == 1 then
                s.control = index
                vim.api.nvim_win_set_cursor(0, { 1, s.buttons[index].first })
                update_focus(s)
            end
        end)
    end
    if name == 'modes' then
        vim.keymap.set('n', '<CR>', function() focus(s, 'query', nil, false) end, { buffer = buf, silent = true })
    elseif name == 'results' then
        vim.keymap.set('n', '<CR>', function() goto_result(s) end, { buffer = buf, silent = true })
    elseif name == 'controls' then
        local function activate()
            if s.applying then return end
            if vim.fn.line('.') == action_row and replacing(s) then replace_all(s); return end
            if vim.fn.line('.') ~= 1 then return end
            local button = s.buttons[button_index(s)]
            s.options[button.key] = not s.options[button.key]
            if button.key == 'extended' then render(s) else request(s); layout(s) end
            if s.options[button.key] then
                if button.key == 'replace' then focus(s, 'replacement') end
                if button.key == 'filters' then focus(s, 'include') end
            end
        end
        vim.keymap.set('n', '<Space>', activate, { buffer = buf, silent = true })
        vim.keymap.set('n', '<CR>', activate, { buffer = buf, silent = true })
    end
    return buf
end

local function window(s, key)
    local buf = s.bufs[key]
    if not buf or not vim.api.nvim_buf_is_valid(buf) then buf = new_buffer(s, key, s.values[key]) end
    local win = vim.api.nvim_get_current_win()
    s.wins[key] = win
    vim.api.nvim_win_set_buf(win, buf)
    for option, value in pairs({ number = false, relativenumber = false, signcolumn = 'no', wrap = false,
        foldenable = false, spell = false, winfixheight = key ~= 'results',
        winhighlight = 'NormalNC:Normal,WinBar:Normal,WinBarNC:Normal' }) do vim.wo[win][option] = value end
    vim.wo[win].winbar = key == 'modes' and ' ' or labels[key] and key ~= 'query' and ('%#Title#' .. labels[key]) or ''
end

layout = function(s)
    if not s.tab or s.tab ~= vim.api.nvim_get_current_tabpage() or s.layouting then return end
    s.layouting = true
    local current = vim.api.nvim_get_current_win()
    s.order = { 'modes', 'query' }
    if replacing(s) then table.insert(s.order, 'replacement') end
    if s.mode == 'files' and s.options.filters then vim.list_extend(s.order, { 'include', 'exclude' }) end
    for _, key in ipairs({ 'replacement', 'include', 'exclude' }) do
        local wanted = vim.tbl_contains(s.order, key)
        if not wanted and s.wins[key] then
            vim.api.nvim_win_close(s.wins[key], true)
            s.wins[key] = nil
        end
    end
    for i = #s.order, 3, -1 do
        local key = s.order[i]
        if not s.wins[key] then
            vim.api.nvim_set_current_win(s.wins[s.order[i + 1] or 'controls'])
            vim.cmd 'aboveleft 1new'
            window(s, key)
        end
    end
    vim.list_extend(s.order, { 'controls', 'results' })
    if vim.api.nvim_win_is_valid(current) then vim.api.nvim_set_current_win(current) end
    resize(s)
    render(s)
    s.layouting = false
end

close = function(s, remembered)
    if s.closing then return end
    if not remembered then remember(s) end
    local ready = s.result_version == s.version
    s.resume = s.status == 'searching' or s.applying or (not ready and (s.values.query ~= '' or s.status ~= 'empty'))
    s.closing = true
    stop(s)
    if ready then s.result_version = s.version end
    local tab = s.tab
    local current = vim.api.nvim_get_current_tabpage() == tab
    s.tab = nil
    if tab and vim.api.nvim_tabpage_is_valid(tab) then
        if #vim.api.nvim_list_tabpages() == 1 then vim.cmd 'tabnew' end
        vim.cmd('tabclose! ' .. vim.api.nvim_tabpage_get_number(tab))
    end
    s.wins = {}
    if active == s then active = nil end
    s.closing = false
    if current and vim.api.nvim_tabpage_is_valid(s.origin_tab) then
        vim.api.nvim_set_current_tabpage(s.origin_tab)
        if vim.api.nvim_win_is_valid(s.origin_win) then vim.api.nvim_set_current_win(s.origin_win) end
    end
end

local function project_state(cwd)
    local project = views[cwd]
    if not project then project = { mode = 'files', states = {} }; views[cwd] = project end
    local s = project.states[project.mode]
    if not s then
        serial = serial + 1
        s = { id = serial, cwd = cwd, version = 0, values = { query = '', replacement = '', include = '', exclude = '' },
            options = project.mode == 'commits' and { extended = true, body = true } or {},
            bufs = {}, wins = {}, cursors = {}, rows = {}, status = 'empty', mode = project.mode, project = project }
        project.states[project.mode] = s
    end
    return s, project
end

local function open_tab(s)
    if s.tab and vim.api.nvim_tabpage_is_valid(s.tab) then vim.api.nvim_set_current_tabpage(s.tab); return end
    local results = s.bufs.results
    if not results or not vim.api.nvim_buf_is_valid(results) then results = new_buffer(s, 'results') end
    vim.cmd('0tab sbuffer ' .. results)
    s.tab = vim.api.nvim_get_current_tabpage()
    vim.t[s.tab].project_search = true
    vim.cmd('tcd ' .. vim.fn.fnameescape(s.cwd))
    window(s, 'results')
    vim.cmd 'topleft 1new'
    window(s, 'query')
    vim.cmd 'belowright 1new'
    window(s, 'controls')
    vim.api.nvim_set_current_win(s.wins.query)
    vim.cmd 'topleft 1new'
    window(s, 'modes')
end

local function restore_view(s)
    local saved = s.saved
    if not saved or not saved.focus or not s.wins[saved.focus] then
        focus(s, 'query')
        vim.cmd 'startinsert!'
        return
    end
    vim.api.nvim_set_current_win(s.wins[saved.focus])
    resize(s)
    if saved.lines == vim.o.lines and saved.columns == vim.o.columns then
        for key, height in pairs(saved.heights) do
            if s.wins[key] then vim.api.nvim_win_set_height(s.wins[key], height) end
        end
    end
    for key, view in pairs(saved.views) do
        if s.wins[key] then vim.api.nvim_win_call(s.wins[key], function() vim.fn.winrestview(view) end) end
    end
    if saved.mode == 'i' and labels[saved.focus] and not s.applying then
        local view, win = saved.views[saved.focus], s.wins[saved.focus]
        -- Entering Insert mode resets the preferred column after winrestview().
        vim.api.nvim_create_autocmd('ModeChanged', { group = group, pattern = '*:i', once = true, callback = function()
            if vim.api.nvim_get_current_win() == win then vim.fn.winrestview(view) end
        end })
        vim.cmd(view.col == #vim.api.nvim_get_current_line() and 'startinsert!' or 'startinsert')
    end
    update_focus(s)
end

function M.open(source_mode, focus_mode, scope)
    local from_search = vim.bo.filetype == 'projectsearch'
    local cwd = scope or vim.uv.fs_realpath(vim.fn.getcwd()) or vim.fn.getcwd()
    local origin_tab, origin_win = vim.api.nvim_get_current_tabpage(), vim.api.nvim_get_current_win()
    if active and active.tab == origin_tab then origin_tab, origin_win = active.origin_tab, active.origin_win end
    local s, project = project_state(cwd)
    if active and active ~= s then close(active) end
    active = s
    if vim.api.nvim_get_current_tabpage() == s.tab then remember(s, from_search and source_mode or nil) end
    if vim.api.nvim_get_current_tabpage() ~= s.tab then
        s.origin_tab, s.origin_win = origin_tab, origin_win
    end
    s.opening = true
    vim.cmd 'stopinsert'
    open_tab(s)
    vim.t[s.tab].project_search_origin = s.origin_tab
    vim.cmd 'tabmove 0'
    if not s.saved or s.resume then request(s, 0, true); s.resume = false end
    layout(s)
    if focus_mode then
        focus(s, 'modes', nil, false)
    else
        restore_view(s)
    end
    s.opening = false
    project.probe = (project.probe or 0) + 1
    local probe = project.probe
    history.probe(cwd, function(root)
        if project.probe ~= probe then return end
        project.root = root
        if active and active.project == project and active.tab then
            if not root and active.mode == 'commits' then change_mode(active, 'files') else render(active) end
        end
    end)
    return s
end

change_mode = function(s, mode)
    if s.mode == mode or s.applying then return end
    close(s)
    s.project.mode = mode
    M.open(nil, true, s.cwd)
end

vim.api.nvim_create_autocmd({ 'WinEnter', 'CursorMoved', 'ModeChanged' }, { group = group, callback = function()
    if active and active.tab == vim.api.nvim_get_current_tabpage() and not active.layouting then update_focus(active) end
end })
vim.api.nvim_create_autocmd({ 'TabLeave', 'WinLeave' }, { group = group, callback = function()
    if active then remember(active) end
end })

vim.api.nvim_create_autocmd('WinClosed', { group = group, callback = function(event)
    local s = active
    if exiting or not s or s.closing or s.layouting then return end
    if vim.tbl_contains(vim.tbl_values(s.wins), tonumber(event.match)) then
        local tab = s.tab
        vim.schedule(function() if s.tab == tab then close(s, true) end end)
    end
end })
vim.api.nvim_create_autocmd('VimResized', { group = group, callback = function()
    if active and active.tab == vim.api.nvim_get_current_tabpage() then layout(active) end
end })
vim.api.nvim_create_autocmd('VimLeavePre', { group = group, callback = function()
    exiting = true
    for _, project in pairs(views) do for _, s in pairs(project.states) do stop(s) end end
end })

return M
