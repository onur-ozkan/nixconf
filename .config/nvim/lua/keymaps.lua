local function map(mode, lhs, rhs, opts)
    vim.keymap.set(mode, lhs, rhs, opts or {})
end

local function setup()
    -- Jump back to the last buffer.
    map('n', '<S-h>', '<C-6><CR>')

    map('n', '`', '<Cmd>NvimTreeToggle<CR>', { silent = true })
    map('n', '<BS>', function()
        require('cfg_git').toggle()
    end, { silent = true, desc = 'Toggle Git changes sidebar' })
    map('n', '<C-f>', function()
        require('cfg_search').open()
    end, { silent = true, desc = 'Open project search and replace' })
    map('i', '<C-f>', '<Esc><Cmd>lua require("cfg_search").open("i")<CR>',
        { silent = true, desc = 'Open project search and replace' })

    map('n', '<C-g>', function() require('cfg_history').open() end, { silent = true, desc = 'Line commit / path history' })

    -- Copy selection to the system clipboard.
    map('v', '<leader>y', '"+y')

    -- Focus the adjacent editor pane or sidebar.
    map('n', '<C-h>', '<Cmd>wincmd h<CR>', { silent = true, desc = 'Focus pane left' })
    map('n', '<C-l>', '<Cmd>wincmd l<CR>', { silent = true, desc = 'Focus pane right' })
    map('n', '<C-k>', '<Cmd>wincmd k<CR>', { silent = true, desc = 'Focus pane above' })
    map('n', '<C-j>', '<Cmd>wincmd j<CR>', { silent = true, desc = 'Focus pane below' })

    map({ 'n', 'x', 's', 'o' }, '<S-Left>', '<Cmd>vertical resize +3<CR>', { silent = true })
    map({ 'n', 'x', 's', 'o' }, '<S-Right>', '<Cmd>vertical resize -3<CR>', { silent = true })
    map({ 'n', 'x', 's', 'o' }, '<S-Up>', '<Cmd>resize +3<CR>', { silent = true })
    map({ 'n', 'x', 's', 'o' }, '<S-Down>', '<Cmd>resize -3<CR>', { silent = true })

    -- Move selected lines; use V first to move a single line.
    map('v', '<C-j>', ":m '>+1<CR>gv=gv")
    map('v', '<C-k>', ":m '<-2<CR>gv=gv")

    -- Map 1T..12T to tab jumps.
    for index = 1, 12 do
        map('n', index .. 'T', function() require('tab_id').go(index) end)
    end
    map('n', 'gt', function()
        if vim.v.count > 0 then require('tab_id').go(vim.v.count) else require('tab_id').cycle(1) end
    end)
    map('n', 'gT', function() require('tab_id').cycle(-vim.v.count1) end)
end

return setup
