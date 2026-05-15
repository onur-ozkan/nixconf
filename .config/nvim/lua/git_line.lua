local function notify(message)
    vim.api.nvim_echo({ { message } }, false, {})
end

local function git_command(base_args, extra_args)
    return vim.list_extend(vim.deepcopy(base_args), extra_args)
end

local function show_current_line()
    -- Use the current file and cursor line.
    local file = vim.fn.expand('%:p')

    if file == '' or vim.fn.filereadable(file) == 0 then
        notify('No file to blame')
        return
    end

    local git_args = { 'git', '-C', vim.fn.fnamemodify(file, ':h') }
    local inside_work_tree = vim.fn.system(git_command(git_args, { 'rev-parse', '--is-inside-work-tree' }))

    if not inside_work_tree:match('true') then
        notify('Not inside a git repository')
        return
    end

    local line_number = vim.fn.line('.')
    -- Ask git blame for only the current line.
    local blame_output = vim.fn.systemlist(git_command(git_args, {
        'blame',
        '--porcelain',
        '-L',
        string.format('%d,%d', line_number, line_number),
        '--',
        file,
    }))
    local commit = ((blame_output[1] or ''):match('^(%S+)')) or ''

    if commit == '' then
        notify('Git blame failed')
        return
    end

    if commit:match('^0+$') then
        notify('Line not committed yet')
        return
    end

    local details = vim.fn.systemlist(git_command(git_args, { 'show', commit }))

    if vim.v.shell_error ~= 0 or vim.tbl_isempty(details) then
        notify('Git show failed')
        return
    end

    -- Open the commit diff in a throwaway tab.
    vim.cmd.tabnew()

    local buffer = vim.api.nvim_get_current_buf()
    vim.bo[buffer].buftype = 'nofile'
    vim.bo[buffer].bufhidden = 'wipe'
    vim.bo[buffer].buflisted = false
    vim.bo[buffer].swapfile = false

    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, details)
    vim.bo[buffer].filetype = 'diff'
    -- Name the tab after the short commit id.
    vim.cmd('file [' .. commit:sub(1, 8) .. ']')
    vim.bo[buffer].modifiable = false
end

return show_current_line
