
let s:TEST_LOG = expand('<sfile>:h:h:gs?\?/?') . '/test.log'
let s:FILETYPE = 'near'

let g:near_ignore = get(g:, 'near_ignore', ['node_modules', '.git', '.svn', '_svn', '.dotnet', 'desktop.ini'])

function! near#open(q_args, ...) abort
	let rootdir = s:fix_path(isdirectory(expand(a:q_args)) ? expand(a:q_args) : getcwd())
	let depth = get(a:000, 0, 1)
	if depth <= 0
		let depth = 1
	endif
	let lines = s:readdir_rec(rootdir, rootdir, depth)
	if !empty(lines)
		if &filetype == s:FILETYPE
			call near#close()
		endif
		let t:near = {
			\ 'prev_view' : winsaveview(),
			\ 'prev_winid' : win_getid(),
			\ 'rootdir' : rootdir,
			\ }
		vnew
		let t:near['near_winid'] = win_getid()
		setlocal noreadonly modified
		silent! call deletebufline('%', 1, '$')
		call setbufline('%', 1, lines)
		let width = max(map(copy(lines), { _,x -> strdisplaywidth(x) })) + 1
		execute printf('vertical resize %d', width)
		setlocal buftype=nofile readonly nomodified nobuflisted
		let &l:filetype = s:FILETYPE
		let &l:statusline = printf('[%s] %s', s:FILETYPE, rootdir)
	else
		call s:error(printf('There are no files or directories in "%s".', rootdir))
	endif
endfunction

function! near#close() abort
	call s:construct_or_init(v:false)
	if (t:near['near_winid'] == win_getid()) && (&filetype == s:FILETYPE)
		close
		if (0 < win_id2win(t:near['prev_winid'])) && !empty(t:near['prev_view'])
			execute printf('%dwincmd w', win_id2win(t:near['prev_winid']))
			call winrestview(t:near['prev_view'])
		endif
		call s:construct_or_init(v:true)
	endif
endfunction

function! near#run_tests() abort
	let saved_wildignore = &wildignore
	try
		if filereadable(s:TEST_LOG)
			call delete(s:TEST_LOG)
		endif
		let v:errors = []
		set wildignore=*.gif
		if has('nvim')
			set wildignore+=.nvimlog
		endif

		call assert_equal(
			\ sort([]),
			\ sort(s:readdir_rec('.', '.', 0)))
		call assert_equal(
			\ sort(['.github/', 'LICENSE', 'README.md', 'autoload/', 'plugin/', 'syntax/']),
			\ sort(s:readdir_rec('.', '.', 1)))
		call assert_equal(
			\ sort(['.github/', '.github/workflows/', 'LICENSE', 'README.md', 'autoload/', 'autoload/near.vim', 'plugin/', 'plugin/near.vim', 'syntax/', 'syntax/near.vim']),
			\ sort(s:readdir_rec('.', '.', 2)))
		call assert_equal(
			\ sort(['.github/', '.github/workflows/', '.github/workflows/neovim.yml', '.github/workflows/vim.yml', 'LICENSE', 'README.md', 'autoload/', 'autoload/near.vim', 'plugin/', 'plugin/near.vim', 'syntax/', 'syntax/near.vim']),
			\ sort(s:readdir_rec('.', '.', 3)))
		call assert_equal(
			\ sort([]),
			\ sort(s:readdir_rec('./plugin', './plugin', 0)))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./plugin', './plugin', 1)))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./plugin', './plugin', 2)))
		call assert_equal(
			\ sort([]),
			\ sort(s:readdir_rec('./syntax', './syntax', 0)))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./syntax', './syntax', 1)))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./syntax', './syntax', 2)))
		call assert_equal(
			\ sort([]),
			\ sort(s:readdir_rec('./.github', './.github', 0)))
		call assert_equal(
			\ sort(['workflows/']),
			\ sort(s:readdir_rec('./.github', './.github', 1)))
		call assert_equal(
			\ sort(['workflows/', 'workflows/neovim.yml', 'workflows/vim.yml']),
			\ sort(s:readdir_rec('./.github', './.github', 2)))

		if !empty(v:errors)
			call writefile(v:errors, s:TEST_LOG)
			for err in v:errors
				call s:error(err)
			endfor
		endif
	finally
		let &wildignore = saved_wildignore
	endtry
endfunction

function! near#select_file(line) abort
	call s:construct_or_init(v:false)
	if (t:near['near_winid'] == win_getid()) && (&filetype == s:FILETYPE)
		let path = s:fix_path(t:near['rootdir'] .. '/' .. a:line)
		if filereadable(path)
			call near#close()
			if -1 == bufnr(path)
				execute printf('edit %s', escape(path, '\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call near#open(path)
		endif
	endif
endfunction



function! s:error(text) abort
	echohl Error
	echo a:text
	echohl None
endfunction

function! s:construct_or_init(force_init) abort
	if a:force_init
		let t:near = {}
	else
		let t:near = get(t:, 'near', {})
	endif
	let t:near['near_winid'] = get(t:near, 'near_winid', -1)
	let t:near['prev_view'] = get(t:near, 'prev_view', {})
	let t:near['prev_winid'] = get(t:near, 'prev_winid', -1)
	let t:near['rootdir'] = get(t:near, 'rootdir', '')
endfunction

function! s:fix_path(path) abort
	return substitute(a:path, '[\/]\+', '/', 'g')
endfunction

function! s:readdir(path) abort
	if exists('*readdir')
		return readdir(a:path)
	else
		let saved = getcwd()
		try
			lcd `=a:path`
			let xs = split(glob('.*') .. "\n" .. glob('*'), "\n")
			call filter(xs, { _,x -> (x != '.') && (x != '..') })
			return xs
		finally
			lcd `=saved`
		endtry
	endif
endfunction

function! s:readdir_rec(rootdir, path, depth) abort
	let xs = []
	if 0 < a:depth
		let rootdir = a:rootdir
		if !empty(rootdir) && ('/' != split(rootdir, '\zs')[-1])
			let rootdir = rootdir .. '/'
		endif
		let names = []
		try
			let names = s:readdir(a:path)
		catch /^Vim\%((\a\+)\)\=:E484:/
			" skip the directory.
			" E484: Can't open file ...
		endtry
		for name in names
			let relpath = s:fix_path(a:path .. '/' .. name)
			if empty(expand(relpath))
				continue
			endif
			if -1 == index(g:near_ignore, name)
				if filereadable(relpath)
					if rootdir == relpath[:len(rootdir) - 1]
						let xs += [relpath[len(rootdir):]]
					else
						let xs += [relpath]
					endif
				elseif isdirectory(relpath)
					if rootdir == relpath[:len(rootdir) - 1]
						let xs += [relpath[len(rootdir):] .. '/']
					else
						let xs += [relpath .. '/']
					endif
					if 0 < a:depth - 1
						let xs += s:readdir_rec(rootdir, relpath, a:depth - 1)
					endif
				endif
			endif
		endfor
	endif
	return xs
endfunction

