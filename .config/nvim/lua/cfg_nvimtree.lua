local nvim_api = require 'nvim-tree.api'
local layout = require 'sidebar_layout'
local M = {}

local ignored_paths = vim.tbl_map(function(path)
    return '^' .. vim.pesc(path) .. '$'
end, { '.git', 'target' })

local function normal_open(action)
    return function()
        require('cfg_history').restore(vim.api.nvim_get_current_tabpage())
        require('git_review').normal_open(action)
    end
end

local function on_attach(bufnr)
    nvim_api.map.on_attach.default(bufnr)

    local opts = { buffer = bufnr, noremap = true, silent = true }
    local open_actions = {}
    for _, action in pairs(nvim_api.node.open) do open_actions[action] = true end
    -- Also handle an already-displayed file, for which opening may only focus
    -- its window and emit no BufWinEnter event.
    for _, mapping in ipairs(vim.api.nvim_buf_get_keymap(bufnr, 'n')) do
        if open_actions[mapping.callback] then
            vim.keymap.set('n', mapping.lhs, normal_open(mapping.callback),
                vim.tbl_extend('force', opts, { desc = mapping.desc, nowait = mapping.nowait == 1 }))
        end
    end

    vim.keymap.set('n', '/', function()
        require('cfg_telescope').find_files()
    end, vim.tbl_extend('force', opts, { desc = 'Live file picker' }))
    vim.keymap.set('n', '<Esc>', nvim_api.tree.close, opts)
    vim.keymap.set('n', '<BS>', function()
        require('cfg_git').toggle()
    end, vim.tbl_extend('force', opts, { desc = 'Toggle Git changes sidebar' }))
    vim.keymap.set('n', 't', normal_open(nvim_api.node.open.tab), opts)
    vim.keymap.set('n', '<C-t>', normal_open(nvim_api.node.open.tab), opts)
    vim.keymap.del('n', '<C-k>', { buffer = bufnr })
    vim.keymap.set('n', '<Tab>', nvim_api.node.show_info_popup,
        vim.tbl_extend('force', opts, { desc = 'File info (Tab / Ctrl+i)' }))
    vim.keymap.set('n', '<C-p>', normal_open(nvim_api.node.open.preview),
        vim.tbl_extend('force', opts, { desc = 'Preview file' }))
end

require'nvim-tree'.setup {
	on_attach = on_attach,
	auto_reload_on_write = true,
	disable_netrw = true,
	hijack_cursor = false,
	hijack_netrw = true,
	hijack_unnamed_buffer_when_opening = false,
	sort_by = "name",
	tab = {
		sync = {
			open = true,
			close = true,
			ignore = { 'projectsearch', 'githistory', 'gitcommitview' },
		},
	},
	view = {
		width = function() return layout.width('NvimTree') end,
		side = "right",
		preserve_window_proportions = true,
		number = true,
		relativenumber = true,
		signcolumn = "yes",
		float = {
			enable = false,
		},
	},
	hijack_directories = {
		enable = false,
		auto_open = false,
	},
	update_focused_file = {
		enable = true,
		ignore_list = {},
	},
	diagnostics = {
		enable = true,
		show_on_dirs = true,
		icons = {
			hint = "",
			info = "",
			warning = "",
			error = "",
		},
	},
	filters = {
		dotfiles = false,
		custom = ignored_paths,
		exclude = {},
	},
	git = {
		enable = true,
		ignore = false,
		timeout = 400,
	},
	renderer = {
		icons = {
			glyphs = {
				default = "",
				symlink = "",
				git = {
					unstaged = "",
					staged = "",
					unmerged = "",
					renamed = "",
					deleted = "",
					untracked = "",
					ignored = "",
				},
				folder = {
					-- arrow_open = "",
					-- arrow_closed = "",
					default = "",
					open = "",
					empty = "",
					empty_open = "",
					symlink = "",
				}
			}
		}
	},
	actions = {
		change_dir = {
			enable = true,
			global = false,
		},
		open_file = {
			quit_on_open = false,
			resize_window = false,
			window_picker = {
				enable = false,
				chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890",
				exclude = {
					filetype = { "notify", "packer", "qf", "diff", "fugitive", "fugitiveblame" },
					buftype = { "nofile", "terminal", "help" },
				},
			},
		},
	},
	trash = {
		cmd = "trash",
		require_confirm = true,
	},
	log = {
		enable = false,
		truncate = false,
		types = {
			all = false,
			config = false,
			copy_paste = false,
			git = false,
			profile = false,
		},
	},
}

nvim_api.events.subscribe(nvim_api.events.Event.TreePreOpen, function()
    local tab = vim.api.nvim_get_current_tabpage()
    local editor = layout.prepare(tab, 'NvimTree')
    if editor then vim.api.nvim_set_current_win(editor) end
end)
nvim_api.events.subscribe(nvim_api.events.Event.TreeOpen, function() layout.finish() end)

-- Synchronize an existing browser without opening it or stealing focus.
function M.review(review)
    local win = nvim_api.tree.winid()
    if not win or not vim.api.nvim_win_is_valid(win) then return end
    if not review then vim.wo[win].cursorline = true; return end
    local path = vim.fs.joinpath(review.root, review.path)
    local real = vim.uv.fs_realpath(path)
    local function located()
        return real and vim.api.nvim_win_call(win, function()
            local node = nvim_api.tree.get_node_under_cursor()
            return node and node.absolute_path and vim.uv.fs_realpath(node.absolute_path) == real or false
        end)
    end
    if real and not located() then
        local relative = vim.fs.relpath(vim.api.nvim_win_call(win, vim.fn.getcwd), path)
        if not relative or relative:match('^%.%./') then nvim_api.tree.change_root(review.root) end
        nvim_api.tree.find_file({ buf = review.buf, open = false, focus = false, update_root = false })
    end
    vim.wo[win].cursorline = not not located()
end

return M
