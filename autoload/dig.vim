
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
		elseif 'goto_gitrootdir' == a:name
			call s:action_goto_gitrootdir()
		elseif 'terminal' == a:name
			call s:action_terminal()
		elseif 'explorer' == a:name
			call s:action_explorer()
		elseif 'search' == a:name
			call s:action_search()
		elseif 'updir' == a:name
			call s:action_updir()
		elseif 'help' == a:name
			call s:action_help()
		elseif 'home' == a:name
			call s:action_home()
		else
			call dig#io#error('Unknown action name: ' .. string(a:name))
		endif
	endif
endfunction



function! s:action_search() abort
	if s:T_DRIVELETTERS == t:dig['type']
		call dig#io#error('Can not search under the driveletters.')
	else
		let pattern = s:input_search_param('pattern',
			\ { v -> !empty(v) },
			\ 'Please type a filename pattern!', '')
		if empty(pattern)
			return
		endif
		let maxdepth = s:input_search_param('max-depth',
			\ { v -> v =~# '^\d\+$' },
			\ 'Please type a number as max-depth!', '3')
		if empty(maxdepth)
			return
		endif
		let rootdir = t:dig['rootdir']
		let t:dig['type'] = s:T_SEARCHRESULT
		setlocal noreadonly modified
		call clearmatches(win_getid())
		call matchadd('Search', '\c' .. pattern[0])
		silent! call deletebufline('%', 1, '$')
		redraw
		call dig#io#search(rootdir, rootdir, pattern[0], str2nr(maxdepth[0]), 1, 1)
		setlocal buftype=nofile readonly nomodified nobuflisted
		echohl Title
		echo 'Search has completed!'
		echohl None
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
			call s:goto_prevwin(v:true)
			call dig#window#open(path, -1)
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
	call s:goto_prevwin(v:false)
	let rootdir = t:dig['rootdir']
	if has('nvim')
		call dig#window#new()
		call termopen(&shell, { 'cwd' : rootdir })
		startinsert
	else
		call term_start(&shell, { 'cwd' : rootdir, 'term_finish' : 'close' })
	endif
endfunction

function! s:action_home() abort
	call dig#open('~')
endfunction

function! s:action_help() abort
	let xs = [
		\ ['l/Enter/Space', 'Open a file or a directory under the cursor.'],
		\ ['Esc', 'Close the dig window.'],
		\ ['d', 'Show git-diff.'],
		\ ['e', 'Open a explorer.exe. (Windows OS only)'],
		\ ['r', 'Go to the git root directory.'],
		\ ['h', 'Go up to parent directory.'],
		\ ['s', 'Search files by filename pattern matching.'],
		\ ['t', 'Open a terminal window.'],
		\ ['~', 'Go to Home directory.'],
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
	let pattern = s:is_dig() ? '' : fnamemodify(bufname(), ':t')
	let prev_winid = ('diff' == &filetype) ? -1 : win_getid()

	let rootdir = get(a:opts, 'rootdir', '')
	if s:T_DRIVELETTERS == a:type
		let rootdir = ''
	else
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
	endif

	if s:is_dig()
		if (get(t:dig, 'dig_winid', -1) != prev_winid) && (-1 != prev_winid)
			let t:dig['prev_winid'] = prev_winid
		endif
		let t:dig['type'] = a:type
	elseif dig#window#find_filetype(s:FILETYPE)
		if (get(t:dig, 'dig_winid', -1) != prev_winid) && (-1 != prev_winid)
			let t:dig['prev_winid'] = prev_winid
		endif
		let t:dig['type'] = a:type
		" Does not change the rootdir if dig window is already opened.
		let rootdir = t:dig['rootdir']
	else
		call dig#window#new()
		let t:dig = {
			\ 'type' : s:T_NORMAL,
			\ 'dig_winid' : win_getid(),
			\ 'prev_winid' : prev_winid,
			\ }
	endif

	wincmd K

	" Change the rootdir and can not open a file
	" because searchresult's path is a relative path.
	if s:T_SEARCHRESULT != t:dig['type']
		let t:dig['rootdir'] = rootdir
	endif

	if has_key(a:opts, 'lines')
		let lines = a:opts['lines']
	elseif s:T_NORMAL != t:dig['type']
		let lines = []
	else
		let lines = dig#io#readdir(rootdir)
	endif

	if !empty(lines)
		setlocal noreadonly modified nonumber
		silent! call deletebufline('%', 1, '$')
		call setbufline('%', 1, lines)
		setlocal buftype=nofile readonly nomodified nobuflisted
		let &l:filetype = s:FILETYPE
		call s:set_statusline()
		if !empty(pattern)
			call search('^' .. pattern .. '$')
			call feedkeys('zz', 'nx')
		endif
	else
		if s:T_NORMAL == t:dig['type']
			call dig#io#error('No file is found.')
		endif
	endif

	call s:adjust_winheight()
endfunction

function! s:adjust_winheight() abort
	resize 10
	setlocal winfixheight
endfunction

function! s:goto_prevwin(p) abort
	call win_gotoid(t:dig['prev_winid'])
	if a:p
		if s:is_dig() || ('terminal' == &buftype) || &modified
			call dig#window#new()
		endif
	endif
endfunction

function! s:set_statusline() abort
	let &l:statusline = printf('[%s:%%{t:dig["type"]}] %%l/%%L', s:FILETYPE)
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

