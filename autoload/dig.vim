
let s:FILETYPE = 'dig'

let s:T_NORMAL = 'normal'
let s:T_DRIVELETTERS = 'driveletters'
let s:T_SEARCHRESULT = 'searchresult'
let s:T_GITDIFF = 'gitdiff'

function! dig#open(q_args) abort
	let t:dig = get(t:, 'dig', {})
	call s:open(get(t:dig, 'type', s:T_NORMAL), {
		\ 'rootdir' : a:q_args,
		\ })
endfunction

function! dig#action(name, ...) abort
	let param = get(a:000, 0, '')
	if s:is_dig()
		if 'select_file' == a:name
			call s:action_select_file(param)
		elseif 'git_diff' == a:name
			call s:action_git_diff()
		elseif 'change_gitrootdir' == a:name
			call s:action_goto_gitrootdir()
		elseif 'terminal' == a:name
			call s:action_terminal()
		elseif 'explorer' == a:name
			call s:action_explorer()
		elseif 'search' == a:name
			call s:action_search()
		elseif 'updir' == a:name
			call s:action_updir()
		elseif 'open_bookmark' == a:name
			call s:action_open_bookmark(param)
		elseif 'change_dir' == a:name
			call s:action_change_dir()
		elseif 'help' == a:name
			call s:action_help()
		else
			call dig#io#error('Unknown action name: ' .. string(a:name))
		endif
	endif
endfunction




function! s:action_search() abort
	if s:T_DRIVELETTERS == t:dig['type']
		call dig#io#error('Can not search under the driveletters.')
	else
		let pattern = s:input_search_param('pattern', { v -> !empty(v) }, 'Please type a filename pattern!', '')
		if empty(pattern)
			return
		endif
		let maxdepth = s:input_search_param('max-depth', { v -> v =~# '^\d\+$' }, 'Please type a number as max-depth!', '3')
		if empty(maxdepth)
			return
		endif
		let rootdir = t:dig['rootdir']
		let t:dig['type'] = s:T_SEARCHRESULT
		setlocal noreadonly modified
		call clearmatches(win_getid())
		call matchadd('Search', '\c' .. pattern[0])
		call s:set_statusline()
		silent! call deletebufline('%', 1, '$')
		redraw
		call dig#io#search(rootdir, rootdir, pattern[0], str2nr(maxdepth[0]), 1, 1)
		setlocal buftype=nofile readonly nomodified nobuflisted
		call s:set_statusline()
		echohl Title
		echo 'Search has completed!'
		echohl None
	endif
endfunction

function! s:action_open_bookmark(n) abort
	let path = get(get(g:, 'dig_bookmarks', {}), a:n, '')
	if !empty(path)
		let path = expand(path)
		if filereadable(path)
			call s:goto_prevwin()
			if (-1 == bufnr(path)) || (fnamemodify(path, ':t') != fnamemodify(bufname(bufnr(path)), ':t'))
				execute printf('edit %s', escape(path, '#\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call s:open(s:T_NORMAL, {
				\ 'rootdir' : path,
				\ })
		endif
	endif
endfunction

function! s:action_select_file(line) abort
	if s:T_GITDIFF == t:dig['type']
		let rootdir = dig#git#rootdir(fnamemodify(t:dig['rootdir'], ':p'))
		call dig#git#show_diff(rootdir, getline('.'))
	elseif s:T_DRIVELETTERS == t:dig['type']
		call s:open(s:T_NORMAL, {
			\ 'rootdir' : a:line,
			\ })
	else
		let path = dig#io#fix_path(t:dig['rootdir'] .. '/' .. a:line)
		if filereadable(path)
			call s:goto_prevwin()
			if (-1 == bufnr(path)) || (fnamemodify(path, ':t') != fnamemodify(bufname(bufnr(path)), ':t'))
				execute printf('edit %s', escape(path, '#\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call s:open(s:T_NORMAL, {
				\ 'rootdir' : path,
				\ })
		endif
	endif
endfunction

function! s:action_updir() abort
	if (s:T_SEARCHRESULT == t:dig['type']) || (s:T_GITDIFF == t:dig['type'])
		if empty(t:dig['rootdir'])
			call s:open(s:T_DRIVELETTERS, {
				\ 'rootdir' : t:dig['rootdir'],
				\ 'lines' : dig#io#driveletters(),
				\ })
		else
			call s:open(s:T_NORMAL,{
				\ 'rootdir' : t:dig['rootdir'],
				\ 'lines' : dig#io#readdir(t:dig['rootdir']),
				\ })
		endif
	elseif s:T_DRIVELETTERS == t:dig['type']
		" nop
	else
		let curdir = fnamemodify(t:dig['rootdir'], ':p:h')
		if -1 != index(dig#io#driveletters(), curdir)
			call s:open(s:T_DRIVELETTERS, {
				\ 'lines' : dig#io#driveletters(),
				\ })
			let pattern = curdir
		else
			let updir = fnamemodify(curdir, ':h')
			call s:open(s:T_NORMAL, {
				\ 'rootdir' : updir,
				\ })
			let pattern = fnamemodify(curdir, ':t') .. '/'
		endif
		call search('^' .. pattern .. '$')
		call feedkeys('zz', 'nx')
	endif
endfunction

function! s:action_change_dir() abort
	let rootdir = t:dig['rootdir']
	let view = winsaveview()
	lcd `=rootdir`
	call s:open(s:T_NORMAL, {
		\ 'rootdir' : rootdir,
		\ })
	call winrestview(view)
endfunction

function! s:action_explorer() abort
	if has('win32')
		let rootdir = fnamemodify(t:dig['rootdir'], ':p')
		execute '!start ' .. rootdir
	endif
endfunction

function! s:action_git_diff() abort
	if executable('git')
		let rootdir = t:dig['rootdir']
		let lines = dig#git#diff(fnamemodify(rootdir, ':p'))
		if empty(lines)
			call dig#io#error('Not a git repository or no modified files.')
		else
			call s:open(s:T_GITDIFF, {
				\ 'rootdir' : rootdir,
				\ 'lines' : lines,
				\ })
			setlocal noreadonly modified
			call clearmatches(win_getid())
			if hlexists('diffAdded')
				call matchadd('diffAdded', '+\d\+')
			elseif hlexists('DiffAdd')
				call matchadd('DiffAdd', '+\d\+')
			endif
			if hlexists('diffRemoved')
				call matchadd('diffRemoved',   '-\d\+')
			elseif hlexists('DiffDelete')
				call matchadd('DiffDelete',   '-\d\+')
			endif
		endif
	endif
endfunction

function! s:action_goto_gitrootdir() abort
	if executable('git')
		let rootdir = dig#git#rootdir(fnamemodify(t:dig['rootdir'], ':p'))
		let view = winsaveview()
		lcd `=rootdir`
		call s:open(s:T_NORMAL, {
			\ 'rootdir' : rootdir,
			\ })
		call winrestview(view)
	endif
endfunction

function! s:action_terminal() abort
	call s:goto_prevwin()
	let rootdir = t:dig['rootdir']
	if has('nvim')
		new
		call termopen(&shell, { 'cwd' : rootdir })
		startinsert
	else
		call term_start(&shell, { 'cwd' : rootdir, 'term_finish' : 'close' })
	endif
endfunction

function! s:action_help() abort
	let xs = [
		\ ['l/Enter/Space', 'Open a file or a directory under the cursor.'],
		\ ['Esc', 'Close the dig window.'],
		\ ['c', 'Set the current directory to the dig''s directory.'],
		\ ['d', 'Show git-diff. (execuable git only)'],
		\ ['e', 'Open a explorer.exe. (Windows OS only)'],
		\ ['r', 'Go to the git root directory.'],
		\ ['h', 'Go up to parent directory.'],
		\ ['s', 'Search a file by filename pattern matching.'],
		\ ['t', 'Open a terminal window.'],
		\ ['~', 'Go to Home directory.'],
		\ ]
	for n in range(1, 9)
		let path = get(get(g:, 'dig_bookmarks', {}), n, '')
		if !empty(path)
			if filereadable(expand(path)) || isdirectory(expand(path))
				let xs += [
					\ [n, printf('Open "%s".', path)],
					\ ]
			endif
		endif
	endfor
	let xs += [
		\ ['?', 'Print this help.'],
		\ ]
	for x in xs
		echohl Title
		echo ' ' .. x[0] .. ' key : '
		echohl None
		echon x[1]
	endfor
endfunction

function! s:open(type, opts) abort
	let opts = a:opts
	let pattern = ''
	let prev_winid = ('diff' == &filetype) ? -1 : win_getid()
	let already_opened = v:false

	let rootdir = get(opts, 'rootdir', '')
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
	let rootdir = dig#io#fix_path(rootdir)

	if s:is_dig()
		let already_opened = v:true
	else
		let pattern = fnamemodify(bufname(), ':t')
		for n in range(1, winnr('$'))
			if s:FILETYPE == getwinvar(n, '&filetype', '')
				execute n .. 'wincmd w'
				let already_opened = v:true
				break
			endif
		endfor
	endif

	if already_opened
		if (get(t:dig, 'dig_winid', -1) != prev_winid) && (-1 != prev_winid)
			let t:dig['prev_winid'] = prev_winid
		endif
	else
		vnew
		wincmd H
		let t:dig = {
			\ 'dig_winid' : win_getid(),
			\ 'prev_winid' : prev_winid,
			\ }
	endif
	let t:dig['type'] = a:type
	if s:T_SEARCHRESULT != t:dig['type']
		let t:dig['rootdir'] = rootdir
	endif

	if has_key(opts, 'lines')
		let lines = opts['lines']
	elseif (s:T_SEARCHRESULT == t:dig['type']) || (s:T_GITDIFF == t:dig['type'])
		let lines = []
	else
		let lines = dig#io#readdir(rootdir)
	endif

	if !empty(lines)
		setlocal noreadonly modified nonumber
		silent! call deletebufline('%', 1, '$')
		call setbufline('%', 1, lines)
		let width = max(map(copy(lines), { _,x -> strdisplaywidth(x) })) + 1
		if width < 16
			let width = 16
		endif
		execute printf('vertical resize %d', width)
		setlocal winfixwidth buftype=nofile readonly nomodified nobuflisted
		let &l:filetype = s:FILETYPE
		call s:set_statusline()
		if !empty(pattern)
			call search('^' .. pattern .. '$')
			call feedkeys('zz', 'nx')
		endif
	endif
endfunction

function! s:goto_prevwin() abort
	call win_gotoid(t:dig['prev_winid'])
	if s:is_dig()
		rightbelow vnew
	endif
endfunction

function! s:set_statusline() abort
	let &l:statusline = printf('[%s:%s] %%l/%%L ', s:FILETYPE, t:dig['type'])
endfunction

function! s:is_dig() abort
	return (get(t:dig, 'dig_winid', -1) == win_getid()) && (&filetype == s:FILETYPE)
endfunction

function! s:input_search_param(name, chk_cb, errmsg, default) abort
	echohl Title
	let v = input(a:name .. '>', a:default)
	echohl None
	if a:chk_cb(v)
		return [v]
	else
		echo ' '
		call dig#io#error(a:errmsg)
		return []
	endif
endfunction

