local telescope = require 'telescope'
local action_state = require 'telescope.actions.state'
local make_entry = require 'telescope.make_entry'
local utils = require 'telescope.utils'

local function compact_vimgrep_entry(opts)
    local base_entry_maker = make_entry.gen_from_vimgrep(opts)

    return function(line)
        local entry = base_entry_maker(line)

        if not entry then
            return nil
        end

        entry.display = function(current_entry)
            local display, path_style = utils.transform_path(opts, current_entry.filename)

            if current_entry.lnum then
                display = string.format('%s:%s', display, current_entry.lnum)
            end

            return display, path_style
        end

        return entry
    end
end

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

    vim.keymap.set('n', '<C-Up>', function()
        vim.cmd(string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', prompt_win))
        vim.cmd 'startinsert'
    end, { buffer = bufnr, noremap = true, silent = true })

    vim.cmd(string.format('noautocmd lua vim.api.nvim_set_current_win(%s)', winid))
    vim.cmd 'stopinsert'
end

local function focus_preview_from_insert(prompt_bufnr)
    focus_preview(prompt_bufnr)
end

local function search_window_options()
    return {
        layout_strategy = 'vertical',
        layout_config = {
            width = 0.88,
            height = 0.9,
            vertical = {
                mirror = true,
                prompt_position = 'top',
                preview_height = function(_, _, height)
                    return math.max(math.floor(height * 0.68), 1)
                end,
            },
        },
        borderchars = {
            prompt = { '─', '│', ' ', '│', '╭', '╮', '│', '│' },
            results = { ' ', '│', '─', '│', '│', '│', '╯', '╰' },
            preview = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
        },
    }
end

telescope.setup {
    defaults = {
        layout_strategy = 'horizontal',
        layout_config = {
            horizontal = {
                preview_width = 0.68,
            },
        },
        mappings = {
            i = {
                ['<C-Down>'] = focus_preview_from_insert,
            },
            n = {
                ['<C-Down>'] = focus_preview,
            },
        },
    },
    pickers = {
        find_files = vim.tbl_extend('force', search_window_options(), {
            prompt_title = 'Find Files',
            results_title = false,
            preview_title = false,
            hidden = true,
            find_command = {
                'rg',
                '--files',
                '--hidden',
                '--glob',
                '!.git',
                '--glob',
                '!.git/**',
            },
        }),
        live_grep = vim.tbl_extend('force', search_window_options(), {
            entry_maker = compact_vimgrep_entry({}),
            prompt_title = 'Search in Files',
            results_title = false,
            preview_title = false,
        }),
        git_status = vim.tbl_extend('force', search_window_options(), {
            prompt_title = 'Status',
            results_title = false,
            preview_title = 'Diff',
        }),
    },
}
