local telescope = require 'telescope'
local actions = require 'telescope.actions'

local M = {}

-- Standalone Telescope picker defaults.
telescope.setup {
    defaults = {
        layout_strategy = 'horizontal',
        layout_config = {
            horizontal = {
                preview_width = 0.68,
            },
        },
    },
    pickers = {
        git_status = {
            layout_strategy = 'vertical',
            layout_config = {
                width = 0.88,
                height = 0.9,
                vertical = {
                    mirror = true,
                    prompt_position = 'top',
                    preview_height = 0.68,
                },
            },
            prompt_title = 'Status',
            results_title = false,
            preview_title = 'Diff',
        },
    },
}

local function file_sorter()
    return require('telescope.sorters').Sorter:new {
        scoring_function = function(_, prompt, path)
            local query = vim.trim(prompt):lower()
            local terms = vim.split(query, '%s+', { trimempty = true })
            local relative = path:lower()
            local filename = vim.fs.basename(relative)
            local filename_match = true
            for _, term in ipairs(terms) do
                -- Require each term literally; scattered letters are too noisy.
                if not relative:find(term, 1, true) then
                    return -1
                end
                filename_match = filename_match and filename:find(term, 1, true) ~= nil
            end

            local rank = 4
            if query == '' then
                return 1
            elseif filename == query then
                rank = 0
            elseif filename:gsub('%.[^.]+$', '') == query then
                rank = 1
            elseif filename:sub(1, #query) == query then
                rank = 2
            elseif filename_match then
                rank = 3
            end
            return rank + #path / (#path + 1)
        end,
        highlighter = function(_, prompt, display)
            local highlights = {}
            for term in prompt:lower():gmatch('%S+') do
                local first, last = display:lower():find(term, 1, true)
                if first then
                    table.insert(highlights, { start = first, finish = last })
                end
            end
            return highlights
        end,
    }
end

function M.find_files()
    local editor_win = vim.fn.win_getid(vim.fn.winnr('#'))
    local function is_editor(win)
        return vim.api.nvim_win_is_valid(win)
            and vim.api.nvim_win_get_config(win).relative == ''
            and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ''
    end

    require('telescope.builtin').find_files {
        cwd = vim.fn.getcwd(),
        hidden = true,
        no_ignore = true,
        find_command = { 'rg', '--files', '--color', 'never', '--glob', '!.git', '--glob', '!target' },
        prompt_prefix = '/',
        prompt_title = false,
        results_title = false,
        previewer = false,
        border = false,
        initial_mode = 'insert',
        sorter = file_sorter(),
        sorting_strategy = 'descending',
        selection_strategy = 'reset',
        scroll_strategy = 'limit',
        layout_strategy = 'bottom_pane',
        layout_config = {
            height = 6,
            prompt_position = 'bottom',
        },
        get_selection_window = function()
            if is_editor(editor_win) then
                return editor_win
            end
            for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
                if is_editor(win) then
                    return win
                end
            end
            vim.cmd 'leftabove vnew'
            return vim.api.nvim_get_current_win()
        end,
        attach_mappings = function(_, map)
            local function move(prompt_bufnr, direction)
                local picker = require('telescope.actions.state').get_current_picker(prompt_bufnr)
                if not picker:get_selection() then
                    return
                end
                local index = picker:get_index(picker:get_selection_row())
                -- Descending results put rank one next to the bottom prompt.
                if (direction < 0 and index < 5) or (direction > 0 and index > 1) then
                    picker:move_selection(direction)
                end
            end
            for _, mode in ipairs({ 'i', 'n' }) do
                map(mode, '<Up>', function(bufnr) move(bufnr, -1) end)
                map(mode, '<Down>', function(bufnr) move(bufnr, 1) end)
                map(mode, '<CR>', actions.select_default)
                map(mode, '<Esc>', actions.close)
            end
            return true
        end,
    }
end

return M
