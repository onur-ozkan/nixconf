local function setup()
    vim.cmd('colorscheme dark-energy')
    vim.cmd('filetype indent plugin on')

    vim.opt.showtabline = 2
    vim.opt.tabline = [[%!v:lua.require('tab_id')()]]
    vim.opt.shortmess:remove('S')

    vim.opt.number = true
    vim.opt.relativenumber = true

    vim.opt.backspace = { 'indent', 'eol', 'start' }
    vim.opt.autoindent = true
    vim.opt.expandtab = false
    vim.opt.tabstop = 4
    vim.opt.shiftwidth = 4
    vim.opt.title = true

    vim.opt.hidden = true
    vim.opt.fixendofline = false
    vim.opt.startofline = false
    vim.opt.splitbelow = true
    vim.opt.splitright = false

    vim.opt.laststatus = 2
    vim.opt.ruler = false
    vim.opt.showmode = false
    vim.opt.signcolumn = 'yes'

    vim.opt.mouse = 'a'
    vim.opt.updatetime = 1000
    vim.opt.ttyfast = true
    vim.opt.lazyredraw = true
    vim.opt.completeopt = { 'menuone', 'noinsert', 'noselect' }
end

return setup
