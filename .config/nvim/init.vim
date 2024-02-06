call plug#begin()
	" Nimda
	Plug 'onur-ozkan-backups/nimda.vim'

	" Telescope
	Plug 'onur-ozkan-backups/plenary.nvim'
	Plug 'onur-ozkan-backups/telescope.nvim'

	" Nvim Tree
	Plug 'onur-ozkan-backups/nvim-tree.lua'

	" Vim Search
	Plug 'onur-ozkan-backups/vim-esearch'

	" Nvim LspConfig
	Plug 'onur-ozkan-backups/nvim-lspconfig'

	" Nvim Cmp
	Plug 'onur-ozkan-backups/nvim-cmp'
	Plug 'onur-ozkan-backups/cmp-nvim-lsp'

	" Treesitter
	Plug 'onur-ozkan-backups/nvim-treesitter', {'do': ':TSUpdate'}

	" Lualine
	Plug 'onur-ozkan-backups/lualine.nvim'

	" Lualine
	Plug 'onur-ozkan-backups/neoconf.nvim'
call plug#end()

" Mappings {
	" Back to previously opened window
	nnoremap <S-h> <C-6> <CR>
	" Open file explorer
	nnoremap <silent> ` :NvimTreeToggle <CR>
	" File search
	nnoremap <silent> <space>` :Telescope find_files <CR>
	" Display git status
	nnoremap <BS> :Telescope git_status <CR>
	" Grep for string that is under the cursor
	nnoremap <C-n> :Telescope grep_string <CR>
	" Grep in whole workspace
	nnoremap <C-f> :Telescope live_grep <CR>
	" Lists git commits with diff preview, checkout action <cr>, reset mixed <C-r>m, reset soft <C-r>s and reset hard <C-r>h
	nnoremap <C-g> :Telescope git_commits <CR>
	" Copy to clipboard
	vnoremap  <leader>y  "+y

	" Auto-closing
	" inoremap ( ()<Left>
	" inoremap [ []<Left>
	" inoremap { {}<Left>
	" inoremap " ""<Left>
	" inoremap ' ''<Left>
	" inoremap ` ``<Left>

	" Window sizing
	noremap <silent> <S-Left> :vertical resize +3<CR>
	noremap <silent> <S-Right> :vertical resize -3<CR>
	noremap <silent> <S-Up> :resize +3<CR>
	noremap <silent> <S-Down> :resize -3<CR>

	" move lines
	nnoremap <C-j> :m .+1<CR>==
	nnoremap <C-k> :m .-2<CR>==
	vnoremap <C-j> :m '>+1<CR>gv=gv
	vnoremap <C-k> :m '<-2<CR>gv=gv

	" Switch tabs easier
	for i in range(1, 12)
	  execute "nmap ".i."T ".i."gt"
	endfor
" Mappings }

" vim-illuminate {
	augroup illuminate_augroup
		autocmd!
		autocmd VimEnter * hi illuminatedWord cterm=underline gui=underline
	augroup END
" vim-ulluminate }

" Settings {
	set termguicolors
	colorscheme nimda

	set showtabline=2
	set tabline=%!DisplayTabId()

	set shortmess-=S

	hi! Normal ctermbg=NONE guibg=NONE
	hi! NonText ctermbg=NONE guibg=NONE

	silent verbose setlocal omnifunc

	filetype indent plugin on
	if !exists('g:syntax_on') | syntax enable | endif
	set encoding=utf-8
	scriptencoding utf-8

	set number relativenumber

	" Highlight extra white spaces
	match Error /\s\+$/
	autocmd BufWinEnter * match Error /\s\+$/
	autocmd BufWinLeave * call clearmatches()

	set backspace=indent,eol,start
	set autoindent noexpandtab tabstop=4 shiftwidth=4
	set title

	set hidden
	set nofixendofline
	set nostartofline
	set splitbelow
	set splitright

	set hlsearch
	set incsearch
	set laststatus=2
	set noruler
	set noshowmode
	set signcolumn=yes

	set mouse=a
	set updatetime=1000

	set ttyfast
	set lazyredraw

	" Set completeopt to have a better completion experience
	set completeopt=menuone,noinsert,noselect

	let g:loaded_python3_provider = 0
	let g:loaded_node_provider = 0
	let g:loaded_perl_provider = 0
	let g:loaded_ruby_provider = 0

	let g:esearch = {}
	" Set the root as current working directory as default for esearch plugin
	let g:esearch.root_markers = []
" Settings }

" Functions }
	function! DisplayTabId()
		let s = ''
		for i in range(tabpagenr('$'))
			let tab = i + 1
			let winnr = tabpagewinnr(tab)
			let buflist = tabpagebuflist(tab)
			let bufnr = buflist[winnr - 1]
			let bufname = bufname(bufnr)
			let bufmodified = getbufvar(bufnr, "&mod")

			let s .= '%' . tab . 'T'
			let s .= (tab == tabpagenr() ? '%#TabLineSel#' : '%#TabLine#')
			let s .= ' [' . tab .'] '
			let s .= (bufname != '' ?  fnamemodify(bufname, ':t') . ' ' : '[No Name] ')
			if bufmodified
				let s .= '• '
			endif
		endfor

		let s .= '%#TabLineFill#'
		if (exists("g:tablineclosebutton"))
			let s .= '%=%999XX'
		endif
		return s
	endfunction
" Functions }

lua require("neoconf").setup({})

lua require('./cfg_lualine')
lua require('./cfg_nvimtree')
lua require('./cfg_lsp')
lua require('./cfg_treesitter')
