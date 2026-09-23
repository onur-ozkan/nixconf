local nvim_api = require 'nvim-tree.api'

local ignored_paths = vim.tbl_map(function(path)
    return '^' .. vim.pesc(path) .. '$'
end, { '.git', 'target' })

local function on_attach(bufnr)
    nvim_api.map.on_attach.default(bufnr)

    local opts = { buffer = bufnr, noremap = true, silent = true }

    vim.keymap.set('n', '/', function()
        require('cfg_telescope').find_files()
    end, vim.tbl_extend('force', opts, { desc = 'Live file picker' }))
    vim.keymap.set('n', '<Esc>', nvim_api.tree.close, opts)
    vim.keymap.set('n', 't', nvim_api.node.open.tab, opts)
    vim.keymap.set('n', '<C-t>', nvim_api.node.open.tab, opts)
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
		},
	},
	view = {
		width = 40,
		side = "right",
		preserve_window_proportions = false,
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
			resize_window = true,
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
