
let s:TEST_LOG = expand('<sfile>:h:h:h:gs?\?/?') . '/test.log'

function! dig#test#run() abort
	let saved_wildignore = &wildignore
	try
		if filereadable(s:TEST_LOG)
			call delete(s:TEST_LOG)
		endif
		let v:errors = []
		set wildignore=*.md
		if has('nvim')
			set wildignore+=.nvimlog
		endif

		call assert_equal(
			\ sort(['.git/', '.github/', 'LICENSE', 'autoload/', 'doc/', 'plugin/', 'syntax/']),
			\ sort(dig#io#readdir('.')))
		call assert_equal(
			\ sort(['dig.vim', 'dig/']),
			\ sort(dig#io#readdir('./autoload')))
		call assert_equal(
			\ sort(['git.vim', 'io.vim', 'sillyiconv.vim', 'test.vim']),
			\ sort(dig#io#readdir('./autoload/dig')))
		call assert_equal(
			\ sort(['dig.vim']),
			\ sort(dig#io#readdir('./plugin')))
		call assert_equal(
			\ sort(['dig.vim']),
			\ sort(dig#io#readdir('./syntax')))
		call assert_equal(
			\ sort(['workflows/']),
			\ sort(dig#io#readdir('./.github')))
		call assert_equal(
			\ sort(['neovim.yml', 'vim.yml']),
			\ sort(dig#io#readdir('./.github/workflows')))

		if !empty(v:errors)
			call writefile(v:errors, s:TEST_LOG)
			for err in v:errors
				call dig#io#error(err)
			endfor
		endif
	finally
		let &wildignore = saved_wildignore
	endtry
endfunction
