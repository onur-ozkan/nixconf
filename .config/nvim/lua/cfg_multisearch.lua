local M = {}

local views = { 'Grep', 'Commits' }
local state = {
    active = false,
    closing = false,
    view = 'Grep',
    wins = {},
    bufs = {},
    content_win = nil,
    content_buf = nil,
    queries = { Grep = '', Commits = '' },
    results = {},
    cwd = nil,
    request_id = 0,
    preview_id = 0,
    setting_prompt = false,
}

local augroup = vim.api.nvim_create_augroup('Multisearch', { clear = true })

local function valid(winid)
    return winid and vim.api.nvim_win_is_valid(winid)
end

local function close_win(winid)
    if valid(winid) then
        vim.api.nvim_win_close(winid, true)
    end
end

local function normal_float(bufnr, config, enter)
    local winid = vim.api.nvim_open_win(bufnr, enter or false, config)
    vim.wo[winid].number = false
    vim.wo[winid].relativenumber = false
    vim.wo[winid].signcolumn = 'no'
    vim.wo[winid].cursorline = true
    -- Match the NvimTree background in every pane.
    vim.wo[winid].winhighlight = 'Normal:NvimTreeNormal,NormalNC:NvimTreeNormal,NormalFloat:NvimTreeNormal,FloatBorder:NvimTreeNormalFloatBorder'
    return winid
end

local function geometry()
    local width = math.min(math.max(math.floor(vim.o.columns * 0.88), 60), vim.o.columns - 4)
    local height = math.min(math.max(math.floor(vim.o.lines * 0.88), 18), vim.o.lines - 4)
    local row = math.max(math.floor((vim.o.lines - height) / 2), 0)
    local col = math.max(math.floor((vim.o.columns - width) / 2), 0)
    local results_height = math.max(math.floor(height * 0.27), 5)

    return {
        relative = 'editor',
        width = width,
        row = row,
        col = col,
        height = height,
        results_height = results_height,
        content_height = math.max(height - results_height - 5, 7),
    }
end

local function float_config(g, row, height, title)
    local config = {
        relative = g.relative,
        width = g.width,
        height = height,
        row = row,
        col = g.col,
        style = 'minimal',
        border = 'rounded',
    }
    if title then
        config.title = title
        config.title_pos = 'center'
    end
    return config
end

local function view_index(view)
    for index, name in ipairs(views) do
        if name == view then
            return index
        end
    end
    return 1
end

local function current_query()
    local bufnr = state.bufs.prompt
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return state.queries[state.view]
    end

    local line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
    local prefix = vim.fn.prompt_getprompt(bufnr)
    return line:sub(#prefix + 1)
end

local function focus_prompt()
    if valid(state.wins.prompt) then
        vim.api.nvim_set_current_win(state.wins.prompt)
        vim.cmd 'startinsert'
    end
end

local focus_content

local function focus_results()
    if valid(state.wins.results) then
        vim.cmd 'stopinsert'
        vim.api.nvim_set_current_win(state.wins.results)
    end
end

focus_content = function()
    if valid(state.content_win) then
        vim.cmd 'stopinsert'
        vim.api.nvim_set_current_win(state.content_win)
    end
end

local function render_tabs()
    local bufnr = state.bufs.tabs
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local labels = {}
    for _, view in ipairs(views) do
        table.insert(labels, view == state.view and ('[ ' .. view .. ' ]') or ('  ' .. view .. '  '))
    end

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { table.concat(labels, ' | ') })
    vim.bo[bufnr].modifiable = false
end

local function render_prompt()
    local bufnr = state.bufs.prompt
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    state.setting_prompt = true
    local prefix = '> '
    vim.fn.prompt_setprompt(bufnr, prefix)
    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { prefix .. state.queries[state.view] })
    vim.bo[bufnr].modifiable = true
    state.setting_prompt = false
end

local function set_results(results)
    state.results = results
    local bufnr = state.bufs.results
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    local lines = {}
    for _, result in ipairs(results) do
        table.insert(lines, result.display)
    end
    if #lines == 0 then
        lines = { 'No results' }
    end

    vim.bo[bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].modifiable = false
    if valid(state.wins.results) then
        vim.api.nvim_win_set_cursor(state.wins.results, { 1, 0 })
    end
end

local function selected_result()
    if not valid(state.wins.results) then
        return nil
    end
    local line = vim.api.nvim_win_get_cursor(state.wins.results)[1]
    return state.results[line]
end

local function clear_content_keymaps(bufnr)
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    for _, mode in ipairs({ 'n', 'i' }) do
        for _, lhs in ipairs({ '<C-Left>', '<C-Right>', '<C-Up>', '<C-Down>' }) do
            pcall(vim.keymap.del, mode, lhs, { buffer = bufnr })
        end
    end
    pcall(vim.keymap.del, 'n', '<Esc>', { buffer = bufnr })
end

local function close_content()
    clear_content_keymaps(state.content_buf)
    close_win(state.content_win)
    state.content_win = nil
    state.content_buf = nil
end

local function close_surface()
    if not state.active or state.closing then
        return
    end

    state.closing = true
    close_content()
    for _, name in ipairs({ 'tabs', 'prompt', 'results' }) do
        close_win(state.wins[name])
    end
    state.wins = {}
    state.bufs = {}
    state.results = {}
    state.active = false
    state.closing = false
end

local function switch_relative(delta)
    local index = view_index(state.view)
    local next_index = ((index - 1 + delta) % #views) + 1
    M.open(views[next_index])
end

local function install_surface_mappings(bufnr, pane)
    local opts = { buffer = bufnr, noremap = true, silent = true }
    vim.keymap.set({ 'n', 'i' }, '<C-Left>', function()
        switch_relative(-1)
    end, opts)
    vim.keymap.set({ 'n', 'i' }, '<C-Right>', function()
        switch_relative(1)
    end, opts)

    if pane == 'prompt' or pane == 'tabs' then
        vim.keymap.set({ 'n', 'i' }, '<C-Down>', focus_results, opts)
        vim.keymap.set({ 'n', 'i' }, '<C-Up>', focus_prompt, opts)
    elseif pane == 'results' then
        vim.keymap.set('n', '<C-Down>', focus_content, opts)
        vim.keymap.set('n', '<C-Up>', focus_prompt, opts)
    elseif pane == 'content' then
        vim.keymap.set({ 'n', 'i' }, '<C-Up>', focus_results, opts)
        vim.keymap.set({ 'n', 'i' }, '<C-Down>', focus_content, opts)
    end
end

local function install_content_mappings(bufnr)
    clear_content_keymaps(bufnr)
    install_surface_mappings(bufnr, 'content')
    vim.keymap.set('n', '<Esc>', close_surface, { buffer = bufnr, noremap = true, silent = true })
end

local function show_text_preview(result)
    if not result or not result.path or not valid(state.content_win) then
        return
    end

    local bufnr = vim.fn.bufadd(result.path)
    vim.fn.bufload(bufnr)
    vim.api.nvim_win_set_buf(state.content_win, bufnr)
    state.content_buf = bufnr
    install_content_mappings(bufnr)
    if result.lnum then
        pcall(vim.api.nvim_win_set_cursor, state.content_win, { result.lnum, math.max(result.col - 1, 0) })
    end
end

local function show_commit_preview(result)
    if not result or not result.hash or not valid(state.content_win) then
        return
    end
    local bufnr = state.content_buf
    if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end

    state.preview_id = state.preview_id + 1
    local preview_id = state.preview_id
    vim.system({ 'git', 'show', '--stat', '--patch', '--color=never', result.hash }, {
        cwd = state.cwd,
        text = true,
    }, function(output)
        vim.schedule(function()
            if not state.active or state.view ~= 'Commits' or preview_id ~= state.preview_id
                or not vim.api.nvim_buf_is_valid(bufnr) then
                return
            end
            local content = output.stdout ~= '' and output.stdout or output.stderr
            local lines = vim.split(content, '\n', { plain = true })
            vim.bo[bufnr].modifiable = true
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
            vim.bo[bufnr].modifiable = false
            vim.bo[bufnr].filetype = 'git'
        end)
    end)
end

local function refresh_grep()
    local query = state.queries.Grep
    if query == '' then
        set_results({ { display = 'Type to search' } })
        return
    end

    state.request_id = state.request_id + 1
    local request_id = state.request_id
    vim.system({ 'rg', '--vimgrep', '--no-heading', '--color=never', '--smart-case', '--hidden', '--glob', '!.git', query, '.' }, {
        cwd = state.cwd,
        text = true,
    }, function(output)
        vim.schedule(function()
            if not state.active or state.view ~= 'Grep' or request_id ~= state.request_id then
                return
            end
            local results = {}
            for _, line in ipairs(vim.split(output.stdout, '\n', { plain = true })) do
                local path, lnum, col, text = line:match('^(.-):(%d+):(%d+):(.*)$')
                if path then
                    table.insert(results, {
                        display = string.format('%s:%s:%s: %s', path, lnum, col, text),
                        path = vim.fs.normalize(state.cwd .. '/' .. path),
                        lnum = tonumber(lnum),
                        col = tonumber(col),
                    })
                end
            end
            set_results(results)
            show_text_preview(results[1])
        end)
    end)
end

local function refresh_commits()
    if not M.in_git_repository() then
        set_results({ { display = 'Not a Git repository' } })
        return
    end

    state.request_id = state.request_id + 1
    local request_id = state.request_id
    local command = { 'git', 'log', '--all', '--date=short', '--pretty=format:%h%x09%s%x09%an%x09%ad' }
    if state.queries.Commits ~= '' then
        table.insert(command, '--grep=' .. state.queries.Commits)
    end
    vim.system(command, { cwd = state.cwd, text = true }, function(output)
        vim.schedule(function()
            if not state.active or state.view ~= 'Commits' or request_id ~= state.request_id then
                return
            end
            local results = {}
            for _, line in ipairs(vim.split(output.stdout, '\n', { plain = true })) do
                local hash, subject, author, date = line:match('^([^\t]+)\t([^\t]*)\t([^\t]*)\t(.*)$')
                if hash then
                    table.insert(results, {
                        display = string.format('%s  %s  — %s (%s)', hash, subject, author, date),
                        hash = hash,
                    })
                end
            end
            set_results(results)
            show_commit_preview(results[1])
        end)
    end)
end

local function refresh_current()
    if state.view == 'Grep' then
        refresh_grep()
    else
        refresh_commits()
    end
end

local function select_result(open_result)
    local result = selected_result()
    if not result then
        return
    end
    if state.view == 'Grep' then
        show_text_preview(result)
        if open_result and result.path then
            close_surface()
            vim.cmd.edit(vim.fn.fnameescape(result.path))
            vim.api.nvim_win_set_cursor(0, { result.lnum, math.max(result.col - 1, 0) })
        end
    elseif state.view == 'Commits' then
        show_commit_preview(result)
    end
end

local function create_content()
    local g = geometry()
    local content_buf = vim.api.nvim_create_buf(false, true)
    local content_win = normal_float(content_buf,
        float_config(g, g.row + g.results_height + 5, g.content_height, state.view), false)
    state.content_win = content_win
    state.content_buf = content_buf

    vim.bo[content_buf].bufhidden = 'wipe'
    vim.bo[content_buf].modifiable = false
    vim.bo[content_buf].filetype = state.view == 'Commits' and 'git' or ''
    install_content_mappings(content_buf)
end

local function configure_results_pane(bufnr)
    vim.bo[bufnr].modifiable = false
    install_surface_mappings(bufnr, 'results')
    vim.keymap.set('n', '<CR>', function()
        select_result(true)
    end, { buffer = bufnr, noremap = true, silent = true })
    vim.keymap.set('n', '<Esc>', close_surface, { buffer = bufnr, noremap = true, silent = true })
    vim.api.nvim_create_autocmd('CursorMoved', {
        group = augroup,
        buffer = bufnr,
        callback = function()
            if state.active then
                select_result(false)
            end
        end,
    })
end

local function create_surface()
    local g = geometry()
    state.bufs.tabs = vim.api.nvim_create_buf(false, true)
    state.bufs.prompt = vim.api.nvim_create_buf(false, true)
    state.bufs.results = vim.api.nvim_create_buf(false, true)

    state.wins.tabs = normal_float(state.bufs.tabs, float_config(g, g.row, 1, 'Multisearch'), false)
    state.wins.prompt = normal_float(state.bufs.prompt, float_config(g, g.row + 2, 1, nil), false)
    state.wins.results = normal_float(state.bufs.results, float_config(g, g.row + 4, g.results_height, nil), false)

    vim.bo[state.bufs.tabs].modifiable = false
    vim.bo[state.bufs.prompt].buftype = 'prompt'
    vim.bo[state.bufs.prompt].modifiable = true
    vim.bo[state.bufs.prompt].filetype = 'MultisearchPrompt'

    install_surface_mappings(state.bufs.tabs, 'tabs')
    install_surface_mappings(state.bufs.prompt, 'prompt')
    configure_results_pane(state.bufs.results)
    vim.keymap.set('n', 'q', close_surface, { buffer = state.bufs.tabs, noremap = true, silent = true })
    vim.keymap.set({ 'n', 'i' }, '<Esc>', close_surface, { buffer = state.bufs.prompt, noremap = true, silent = true })

    vim.fn.prompt_setcallback(state.bufs.prompt, function()
        focus_results()
    end)
    vim.api.nvim_buf_attach(state.bufs.prompt, false, {
        on_lines = function()
            if state.setting_prompt or not state.active then
                return
            end
            vim.schedule(function()
                if state.active and not state.setting_prompt then
                    state.queries[state.view] = current_query()
                    refresh_current()
                end
            end)
        end,
    })
end

function M.in_git_repository()
    return #vim.fs.find('.git', { path = vim.fn.getcwd(), upward = true, limit = 1 }) > 0
end

function M.open(view)
    view = vim.tbl_contains(views, view) and view or 'Grep'
    if not state.active then
        state.active = true
        state.cwd = vim.fn.getcwd()
        create_surface()
    else
        state.queries[state.view] = current_query()
        close_content()
    end

    state.view = view
    render_tabs()
    render_prompt()
    create_content()
    refresh_current()
    focus_prompt()
end

function M.close()
    close_surface()
end

function M.setup()
    vim.api.nvim_create_user_command('Multisearch', function(opts)
        M.open(opts.args ~= '' and opts.args or 'Grep')
    end, {
        nargs = '?',
        complete = function()
            return views
        end,
        desc = 'Open the unified Multisearch surface',
    })
end

M.setup()

return M
