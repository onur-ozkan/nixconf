local function clear_trailing_whitespace()
    local match_id = vim.w.trailing_whitespace_match_id

    if match_id then
        pcall(vim.fn.matchdelete, match_id)
        vim.w.trailing_whitespace_match_id = nil
    end
end

local function highlight_trailing_whitespace()
    clear_trailing_whitespace()
    vim.w.trailing_whitespace_match_id = vim.fn.matchadd('Error', [[\s\+$]])
end

local function setup()
    -- Keep trailing space highlighting window-local.
    local trailing_whitespace_group = vim.api.nvim_create_augroup('TrailingWhitespace', { clear = true })

    vim.api.nvim_create_autocmd('BufWinEnter', {
        group = trailing_whitespace_group,
        callback = highlight_trailing_whitespace,
    })

    vim.api.nvim_create_autocmd('BufWinLeave', {
        group = trailing_whitespace_group,
        callback = clear_trailing_whitespace,
    })

    highlight_trailing_whitespace()
end

return setup
