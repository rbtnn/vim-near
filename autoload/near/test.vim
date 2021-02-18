
let s:TEST_LOG = expand('<sfile>:h:h:h:gs?\?/?') . '/test.log'

function! near#test#run() abort
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
			\ sort(near#io#readdir('.')))
		call assert_equal(
			\ sort(['near.vim', 'near/']),
			\ sort(near#io#readdir('./autoload')))
		call assert_equal(
			\ sort(['io.vim', 'test.vim']),
			\ sort(near#io#readdir('./autoload/near')))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(near#io#readdir('./plugin')))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(near#io#readdir('./syntax')))
		call assert_equal(
			\ sort(['workflows/']),
			\ sort(near#io#readdir('./.github')))
		call assert_equal(
			\ sort(['neovim.yml', 'vim.yml']),
			\ sort(near#io#readdir('./.github/workflows')))

		if !empty(v:errors)
			call writefile(v:errors, s:TEST_LOG)
			for err in v:errors
				call near#io#error(err)
			endfor
		endif
	finally
		let &wildignore = saved_wildignore
	endtry
endfunction

