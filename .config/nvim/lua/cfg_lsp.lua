lspconfig = require 'lspconfig'
-- Use an on_attach function to only map the following keys
-- after the language server attaches to the current buffer
local on_attach = function(client, bufnr)
    local function buf_set_keymap(...)
        vim.api.nvim_buf_set_keymap(bufnr, ...)
    end
    local function buf_set_option(...)
        vim.api.nvim_buf_set_option(bufnr, ...)
    end

    -- Enable completion triggered by <c-x><c-o>
    buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

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
    buf_set_keymap('n', '[d', '<cmd>lua vim.diagnostic.goto_prev()<CR>', opts)
    buf_set_keymap('n', ']d', '<cmd>lua vim.diagnostic.goto_next()<CR>', opts)
    buf_set_keymap('n', 'K', '<cmd>lua vim.lsp.buf.hover()<CR>', opts)
end

-- Diagnostic signs
vim.fn.sign_define("LspDiagnosticsSignError", {
    text = "",
    texthl = ""
})
vim.fn.sign_define("LspDiagnosticsSignWarning", {
    text = "",
    texthl = ""
})
vim.fn.sign_define("LspDiagnosticsSignInformation", {
    text = "",
    texthl = ""
})
vim.fn.sign_define("LspDiagnosticsSignHint", {
    text = "",
    texthl = ""
})

-- Diagnostic prefix
vim.lsp.handlers["textDocument/publishDiagnostics"] = vim.lsp.with(vim.lsp.diagnostic.on_publish_diagnostics, {
    virtual_text = {
        prefix = '■'
    }
})

-- Autocomplete
local cmp = require 'cmp'
local cmp_lsp = require 'cmp_nvim_lsp'

-- returns true when there's space/tab before cursor
local check_back_space = function()
    local col = vim.fn.col '.' - 1
    return col == 0 or vim.fn.getline('.'):sub(col, col):match '%s' ~= nil
end

local has_words_before = function()
    if vim.api.nvim_buf_get_option(0, "buftype") == "prompt" then
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
            vim_itemmenu = ({
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
lspconfig.ccls.setup {
	autostart = false,
	cmd = { 'ccls' },
    on_attach = on_attach,
	capabilities = capabilities,
    init_options = {
        cache = {
            directory = ".cache"
        }
    },
	clang = {
		excludeArgs = { "-frounding-math"},
		extraArgs = { "--gcc-toolchain=/usr"}
    },
	default_config = {
      root_dir = [[root_pattern("compile_commands.json", ".ccls", ".git")]]
    }
}
-- c/cpp

-- rust
lspconfig.rust_analyzer.setup {
	autostart = false,
    on_attach = on_attach,
	capabilities = capabilities
}
-- rust

-- golang
lspconfig.gopls.setup {
	autostart = false,
    on_attach = on_attach,
	capabilities = capabilities
}
-- golang

-- python
lspconfig.pyright.setup {
	autostart = false,
    on_attach = on_attach,
	capabilities = capabilities
}
-- python
