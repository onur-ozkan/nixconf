local function map(mode, lhs, rhs, opts)
    vim.keymap.set(mode, lhs, rhs, opts or {})
end

local function setup()
    -- Jump back to the last buffer.
    map('n', '<S-h>', '<C-6><CR>')

    map('n', '`', '<Cmd>NvimTreeToggle<CR>', { silent = true })
    map('n', '<space>`', '<Cmd>Telescope find_files<CR>', { silent = true })
    map('n', '<BS>', '<Cmd>Telescope git_status<CR>')
    map('n', '<C-g>', '<Cmd>Telescope git_commits<CR>')
    map('n', '<C-n>', '<Cmd>Telescope grep_string<CR>')
    map('n', '<C-f>', '<Cmd>Telescope live_grep<CR>')

    map('n', '<C-l>', '<Cmd>GitLineInfo<CR>')

    -- Copy selection to the system clipboard.
    map('v', '<leader>y', '"+y')

    map({ 'n', 'x', 's', 'o' }, '<S-Left>', '<Cmd>vertical resize +3<CR>', { silent = true })
    map({ 'n', 'x', 's', 'o' }, '<S-Right>', '<Cmd>vertical resize -3<CR>', { silent = true })
    map({ 'n', 'x', 's', 'o' }, '<S-Up>', '<Cmd>resize +3<CR>', { silent = true })
    map({ 'n', 'x', 's', 'o' }, '<S-Down>', '<Cmd>resize -3<CR>', { silent = true })

    -- Move the current line or selected block.
    map('n', '<C-j>', '<Cmd>m .+1<CR>==')
    map('n', '<C-k>', '<Cmd>m .-2<CR>==')
    map('v', '<C-j>', ":m '>+1<CR>gv=gv")
    map('v', '<C-k>', ":m '<-2<CR>gv=gv")

    -- Map 1T..12T to tab jumps.
    for index = 1, 12 do
        map('n', index .. 'T', index .. 'gt')
    end
end

return setup
