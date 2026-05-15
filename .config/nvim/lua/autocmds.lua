local setup_trailing_whitespace = require 'trailing_whitespace'

local function setup()
    local trailing_whitespace_group = vim.api.nvim_create_augroup('TrailingWhitespace', { clear = true })
    setup_trailing_whitespace(trailing_whitespace_group)
end

return setup
