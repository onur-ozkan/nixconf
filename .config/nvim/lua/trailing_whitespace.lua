local function set_highlight()
    vim.api.nvim_set_hl(0, 'TrailingWhitespace', {
        ctermbg = 1,
        bg = '#992f33',
    })
end

local function show()
    vim.cmd([[match TrailingWhitespace /\s\+\%#\@!$/]])
end

local function setup(group)
    set_highlight()

    vim.api.nvim_create_autocmd('ColorScheme', {
        group = group,
        callback = set_highlight,
    })

    vim.api.nvim_create_autocmd({ 'BufEnter', 'WinEnter', 'InsertLeave' }, {
        group = group,
        callback = show,
    })

    show()
end

return setup
