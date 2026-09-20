-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(_, bufnr)
    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end

    -- Enable completion triggered by <c-x><c-o>
    vim.bo[bufnr].omnifunc = 'v:lua.vim.lsp.omnifunc'

    -- Mappings.
    local opts = {
        noremap = true,
        silent = true
    }

    buf_set_keymap('n', 'gD', '<cmd>lua vim.lsp.buf.declaration()<CR>', opts)
    buf_set_keymap('n', 'gd', '<cmd>lua vim.lsp.buf.definition()<CR>', opts)
    buf_set_keymap('n', 'gi', '<cmd>lua vim.api.nvim_command("Telescope lsp_implementations")<CR>', opts)
    buf_set_keymap('n', 'gr', '<cmd>lua vim.api.nvim_command("Telescope lsp_references")<CR>', opts)
    buf_set_keymap('n', '<space>k', '<cmd>lua vim.lsp.buf.signature_help()<CR>', opts)
    buf_set_keymap('n', '<space>wa', '<cmd>lua vim.lsp.buf.add_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wr', '<cmd>lua vim.lsp.buf.remove_workspace_folder()<CR>', opts)
    buf_set_keymap('n', '<space>wl', '<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<CR>', opts)
    buf_set_keymap('n', '<space>D', '<cmd>lua vim.lsp.buf.type_definition()<CR>', opts)
    buf_set_keymap('n', '<space>rn', '<cmd>lua vim.lsp.buf.rename()<CR>', opts)
    buf_set_keymap('n', '<space>ca', '<cmd>lua vim.lsp.buf.code_action()<CR>', opts)
    buf_set_keymap('n', '<space>e', '<cmd>lua vim.diagnostic.open_float()<CR>', opts)
    buf_set_keymap('n', '<space>q', '<cmd>lua vim.api.nvim_command("Telescope diagnostics")<CR>', opts)
    buf_set_keymap('n', '<space>f', '<cmd>lua vim.lsp.buf.format { async = true }<CR>', opts)
    buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.jump({ count = -1, float = true })<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.jump({ count = 1, float = true })<CR>', opts)
    buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
end

-- Diagnostic signs and virtual text use the current Neovim API.
vim.diagnostic.config({
    signs = {
        text = {
            [vim.diagnostic.severity.ERROR] = '',
            [vim.diagnostic.severity.WARN] = '',
            [vim.diagnostic.severity.INFO] = '',
            [vim.diagnostic.severity.HINT] = '',
        },
    },
    virtual_text = { prefix = '■' },
})

-- Autocomplete
local cmp = require 'cmp'

local has_words_before = function()
    if vim.bo[0].buftype == "prompt" then
        return false
    end
    local line, col = unpack(vim.api.nvim_win_get_cursor(0))
    return col ~= 0 and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
end

local capabilities = require('cmp_nvim_lsp').default_capabilities()

capabilities.textDocument.completion.completionItem.snippetSupport = false -- turn off snippets

cmp.setup({
    mapping = {
        ['<Tab>'] = function(fallback)
            if cmp.visible() then
                cmp.select_next_item({ behavior = cmp.SelectBehavior.Select })
            elseif has_words_before() then
                cmp.complete()
            else
                fallback()
            end
        end,
        ['<S-Tab>'] = function(fallback)
            if cmp.visible() then
                cmp.select_prev_item({ behavior = cmp.SelectBehavior.Select })
            elseif has_words_before() then
                cmp.complete()
            else
                fallback()
            end
		end,
		['<CR>'] = cmp.mapping.confirm {
      		behavior = cmp.ConfirmBehavior.Insert,
      		select = true,
    	},
    },
    sources = {{
        name = 'nvim_lsp'
    }, {
        name = 'buffer'
    }, {
        name = 'path'
    }},
    formatting = {
        format = function(entry, vim_item)
            vim_item.menu = ({
                nvim_lsp = "[LSP]",
                buffer = "[BFR]",
                path = "[PTH]"
            })[entry.source.name]
            return vim_item
        end
    }
})

vim.cmd [[
	hi CmpItemKind guifg=#f7ca88
	hi CmpItemMenu guifg=#e3e3e3
	hi CmpItemAbbr guifg=#e3e3e3

	hi CmpItemAbbrMatch guifg=#87af5f guibg=#313131
	hi CmpItemAbbrMatchFuzzy guifg=#87af5f guibg=#313131
]]
-- Autocomplete

-- c/cpp
vim.lsp.config('ccls', {
    on_attach = on_attach,
    capabilities = capabilities,
    root_markers = { 'compile_commands.json', '.ccls', '.git' },
    init_options = {
        cache = { directory = '.cache' },
        clang = {
            excludeArgs = { '-frounding-math' },
            extraArgs = { '--gcc-toolchain=/usr' },
        },
    },
})
-- c/cpp

-- rust
vim.lsp.config('rust_analyzer', {
    on_attach = on_attach,
    capabilities = capabilities,
})

local function rustc_expand()
	local source_name = vim.fn.expand('%:t')
	if source_name == '' then
		source_name = 'buffer'
	end
	local cargo_toml = vim.fs.find('Cargo.toml', {
		path = vim.fn.expand('%:p:h'),
		upward = true,
	})[1]
	if not cargo_toml then
		vim.notify('Cargo.toml not found', vim.log.levels.ERROR)
		return
	end

	vim.system({
		'cargo',
		'rustc',
		'--profile=check',
		'--quiet',
		'--',
		'-Zunpretty=expanded',
	}, {
		cwd = vim.fs.dirname(cargo_toml),
		env = { RUSTC_BOOTSTRAP = '1' },
		text = true,
	}, function(result)
		vim.schedule(function()
			if result.code ~= 0 then
				vim.notify(result.stderr, vim.log.levels.ERROR)
				return
			end

			vim.cmd('tabnew')
			vim.bo.buftype = 'nofile'
			vim.bo.bufhidden = 'wipe'
			vim.bo.swapfile = false
			vim.bo.filetype = 'rust'
			vim.api.nvim_buf_set_name(0, '[RustcExpand: ' .. source_name .. ']')
			vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(result.stdout, '\n', { plain = true }))
			vim.bo.modifiable = false
		end)
	end)
end

vim.api.nvim_create_user_command('RustcExpand', rustc_expand, {})
-- rust

-- golang
vim.lsp.config('gopls', {
	on_attach = on_attach,
	capabilities = capabilities
})
-- golang

-- python
vim.lsp.config('pyright', {
	on_attach = on_attach,
	capabilities = capabilities
})
-- python
