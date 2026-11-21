local group = vim.api.nvim_create_augroup('SidebarSelection', { clear = true })

local function apply()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
        if ft == 'gitstatus' or ft == 'NvimTree' or (ft == 'githistory' and vim.w[win].history_pane == 'commits') then
            vim.wo[win].cursorlineopt = 'both'
        elseif vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' or ft == 'gitcommitview'
            or (ft == 'githistory' and vim.w[win].history_pane == 'diff') then
            vim.wo[win].cursorline = false
            if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == '' and
                (vim.wo[win].winhighlight:find('NvimTree', 1, true) or vim.wo[win].winhighlight:find('SidebarSelection', 1, true)) then
                vim.wo[win].winhighlight, vim.wo[win].winfixwidth = '', false
            end
        end
    end
end

local function highlights()
    vim.api.nvim_set_hl(0, 'GitError', { fg = '#d75f5f', ctermfg = 1 })
    -- Keep replacement lines green and their old text red.
    for name, link in pairs({ MiniDiffOverChange = 'DiffDelete', MiniDiffOverContext = 'DiffDelete',
        MiniDiffOverChangeBuf = 'DiffAdd', MiniDiffOverContextBuf = 'DiffAdd' }) do
        vim.api.nvim_set_hl(0, name, { link = link })
    end
    local visual = vim.api.nvim_get_hl(0, { name = 'Visual', link = false })
    vim.api.nvim_set_hl(0, 'SidebarSelection', { bg = visual.bg, ctermbg = visual.ctermbg })
    vim.api.nvim_set_hl(0, 'NvimTreeCursorLine', { link = 'SidebarSelection' })
    apply()
end

highlights()
vim.api.nvim_create_autocmd('ColorScheme', { group = group, callback = highlights })
vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter', 'WinEnter' }, {
    group = group,
    callback = function()
        vim.schedule(apply)
    end,
})
