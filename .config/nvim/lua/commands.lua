local function setup()
    vim.api.nvim_create_user_command('GitLineInfo', require('git_line'), { force = true })
end

return setup
