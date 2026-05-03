local telescope = require 'telescope'
local action_state = require 'telescope.actions.state'

local function focus_preview(prompt_bufnr)
    local picker = action_state.get_current_picker(prompt_bufnr)
    local prompt_win = picker.prompt_win
    local previewer = picker.previewer

    if not previewer or not previewer.state then
        return
    end

    local bufnr = previewer.state.bufnr or previewer.state.termopen_bufnr
    local winid = previewer.state.winid or (bufnr and vim.fn.win_findbuf(bufnr)[1])

    if not prompt_win or not vim.api.nvim_win_is_valid(prompt_win) then
        return
    end

    if not bufnr or not winid or not vim.api.nvim_win_is_valid(winid) then
        return
    end

    vim.keymap.set('n', '<C-Left>', function()
        vim.cmd(string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', prompt_win))
        vim.cmd 'startinsert'
    end, { buffer = bufnr, noremap = true, silent = true })

    vim.cmd(string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', winid))
    vim.cmd 'stopinsert'
end

local function focus_preview_from_insert(prompt_bufnr)
    focus_preview(prompt_bufnr)
end

telescope.setup {
    defaults = {
        mappings = {
            i = {
                ['<C-Right>'] = focus_preview_from_insert,
            },
            n = {
                ['<C-Right>'] = focus_preview,
            },
        },
    },
}