
let s:TEST_LOG = expand('<sfile>:h:h:gs?\?/?') . '/test.log'
let s:FILETYPE = 'near'

let g:near_ignore = get(g:, 'near_ignore', [ 'desktop.ini', 'System Volume Information', 'Thumbs.db', ])


function! near#open(q_args) abort
	let rootdir = a:q_args
	if empty(rootdir)
	   	if filereadable(bufname())
			let rootdir = fnamemodify(bufname(), ':h')
		else
			let rootdir = getcwd()
		endif
	else
		if isdirectory(expand(rootdir))
			let rootdir = expand(rootdir)
		else
			let rootdir = getcwd()
		endif
	endif
	let rootdir = s:fix_path(rootdir)
	let lines = s:readdir_rec(rootdir, rootdir)
	call s:open(rootdir, lines, v:false)
endfunction

function! s:open(rootdir, lines, is_driveletters) abort
	if !empty(a:lines)
		if &filetype == s:FILETYPE
			call near#close()
		endif
		let t:near = {
			\ 'prev_winid' : win_getid(),
			\ 'rootdir' : a:rootdir,
			\ 'is_driveletters' : a:is_driveletters,
			\ }
		vnew
		let t:near['near_winid'] = win_getid()
		setlocal noreadonly modified
		silent! call deletebufline('%', 1, '$')
		call setbufline('%', 1, a:lines)
		let width = max(map(copy(a:lines), { _,x -> strdisplaywidth(x) })) + 1
		execute printf('vertical resize %d', width)
		setlocal buftype=nofile readonly nomodified nobuflisted
		let &l:filetype = s:FILETYPE
		let &l:statusline = printf('[%s]', s:FILETYPE)
	else
		call s:error(printf('There are no files or directories in "%s".', a:rootdir))
	endif
endfunction

function! near#close() abort
	call s:construct_or_init(v:false)
	if (t:near['near_winid'] == win_getid()) && (&filetype == s:FILETYPE)
		" Does not close the Near window if here is CmdLineWindow.
		if ':' != getcmdtype()
			close
			if 0 < win_id2win(t:near['prev_winid'])
				execute printf('%dwincmd w', win_id2win(t:near['prev_winid']))
			endif
			call s:construct_or_init(v:true)
		endif
	endif
endfunction

function! near#run_tests() abort
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
			\ sort(s:readdir_rec('.', '.')))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./autoload', './autoload')))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./plugin', './plugin')))
		call assert_equal(
			\ sort(['near.vim']),
			\ sort(s:readdir_rec('./syntax', './syntax')))
		call assert_equal(
			\ sort(['workflows/']),
			\ sort(s:readdir_rec('./.github', './.github')))
		call assert_equal(
			\ sort(['neovim.yml', 'vim.yml']),
			\ sort(s:readdir_rec('./.github/workflows', './.github/workflows')))

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
		let path = s:fix_path((t:near['is_driveletters'] ? '' : (t:near['rootdir'] .. '/')) .. a:line)
		if filereadable(path)
			call near#close()
			if -1 == bufnr(path)
				execute printf('edit %s', escape(path, '#\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call near#open(path)
		endif
	endif
endfunction

function! near#updir() abort
	call s:construct_or_init(v:false)
	if !t:near['is_driveletters']
		let curdir = fnamemodify(t:near['rootdir'], ':p:h')
		if -1 != index(s:driveletters(), curdir)
			call s:open('', s:driveletters(), v:true)
		else
			let updir = fnamemodify(curdir, ':h')
			call near#open(updir)
		endif
		let pattern = '^' .. fnamemodify(curdir, ':t') .. '/$'
		call search(pattern)
		call feedkeys('zz', 'nx')
	endif
endfunction

function! near#change_dir() abort
	call s:construct_or_init(v:false)
	let rootdir = t:near['rootdir']
	let view = winsaveview()
	call near#close()
	lcd `=rootdir`
	call near#open(rootdir)
	call winrestview(view)
endfunction

function! near#help() abort
	let xs = [
		\ ['Enter', 'Open a file or a directory under the cursor.'],
		\ ['Space', 'Open a file or a directory under the cursor.'],
		\ ['Esc', 'Close the Near window.'],
		\ ['L', 'Open a file or a directory under the cursor.'],
		\ ['H', 'Go up to parent directory.'],
		\ ['C', 'Change the current directory to the Near''s directory.'],
		\ ['~', 'Change the current directory to Home directory.'],
		\ ['?', 'Print this help.'],
		\ ]
	for x in xs
		echohl Title
		echo x[0] .. ' key : '
		echohl None
		echon x[1]
	endfor
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
	let t:near['prev_winid'] = get(t:near, 'prev_winid', -1)
	let t:near['rootdir'] = get(t:near, 'rootdir', '.')
	let t:near['is_driveletters'] = get(t:near, 'is_driveletters', v:false)
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

function! s:driveletters() abort
	let xs = []
	if has('win32')
		for n in range(char2nr('A'), char2nr('Z'))
			if isdirectory(nr2char(n) .. ':')
				let xs += [nr2char(n) .. ':/']
			endif
		endfor
	endif
	return xs
endfunction

function! s:readdir_rec(rootdir, path) abort
	let xs = []
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
			elseif isdirectory(relpath) && (fnamemodify(name, ':t') !~# '^\$')
				if rootdir == relpath[:len(rootdir) - 1]
					let xs += [relpath[len(rootdir):] .. '/']
				else
					let xs += [relpath .. '/']
				endif
			endif
		endif
	endfor
	return xs
endfunction

