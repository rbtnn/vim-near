
let s:FILETYPE = 'dig'

function! dig#open(q_args) abort
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
	let rootdir = dig#io#fix_path(rootdir)
	let lines = dig#io#readdir(rootdir)
	call s:open(rootdir, lines, v:false, v:false)
endfunction

function! dig#close() abort
	if s:is_dig()
		" Does not close the dig window if here is CmdLineWindow.
		if ':' != getcmdtype()
			close
			if 0 < win_id2win(t:dig['prev_winid'])
				execute printf('%dwincmd w', win_id2win(t:dig['prev_winid']))
			endif
			call s:configure(v:true)
		endif
	endif
endfunction

function! dig#search() abort
	if s:is_dig()
		if t:dig['is_driveletters']
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
			setlocal noreadonly modified
			call clearmatches()
			call matchadd('Search', '\c' .. pattern[0])
			call s:set_statusline()
			silent! call deletebufline('%', 1, '$')
			redraw
			call dig#io#search(rootdir, rootdir, pattern[0], str2nr(maxdepth[0]), 1, 1)
			setlocal buftype=nofile readonly nomodified nobuflisted
			let t:dig['is_searchresult'] = v:true
			call s:set_statusline()
			echohl Title
			echo 'Search has completed!'
			echohl None
		endif
	endif
endfunction

function! dig#select_file(line) abort
	if s:is_dig()
		let path = dig#io#fix_path((t:dig['is_driveletters'] ? '' : (t:dig['rootdir'] .. '/')) .. a:line)
		if filereadable(path)
			call dig#close()
			if -1 == bufnr(path)
				execute printf('edit %s', escape(path, '#\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call dig#open(path)
		endif
	endif
endfunction

function! dig#updir() abort
	if s:is_dig()
		if t:dig['is_searchresult']
			if empty(t:dig['rootdir'])
				call s:open(t:dig['rootdir'], dig#io#driveletters(), v:true, v:false)
			else
				let lines = dig#io#readdir(t:dig['rootdir'])
				call s:open(t:dig['rootdir'], lines, v:false, v:false)
			endif
		elseif t:dig['is_driveletters']
			" nop
		else
			let curdir = fnamemodify(t:dig['rootdir'], ':p:h')
			if -1 != index(dig#io#driveletters(), curdir)
				call s:open('', dig#io#driveletters(), v:true, v:false)
				let pattern = curdir
			else
				let updir = fnamemodify(curdir, ':h')
				call dig#open(updir)
				let pattern = fnamemodify(curdir, ':t') .. '/'
			endif
			call search('^' .. pattern .. '$')
			call feedkeys('zz', 'nx')
		endif
	endif
endfunction

function! dig#change_dir() abort
	if s:is_dig()
		let rootdir = t:dig['rootdir']
		let view = winsaveview()
		call dig#close()
		lcd `=rootdir`
		call dig#open(rootdir)
		call winrestview(view)
	endif
endfunction

function! dig#explorer() abort
	if s:is_dig()
		if has('win32')
			let rootdir = fnamemodify(t:dig['rootdir'], ':p')
			call dig#close()
			execute '!start ' .. rootdir
		endif
	endif
endfunction

function! dig#terminal() abort
	if s:is_dig()
		let rootdir = t:dig['rootdir']
		call dig#close()
		if has('nvim')
			new
			call termopen(&shell, { 'cwd' : rootdir })
			startinsert
		else
			call term_start(&shell, { 'cwd' : rootdir, 'term_finish' : 'close' })
		endif
	endif
endfunction

function! dig#help() abort
	if s:is_dig()
		let xs = [
			\ ['Enter/Space', 'Open a file or a directory under the cursor.'],
			\ ['Esc', 'Close the dig window.'],
			\ ['T', 'Open a terminal window.'],
			\ ['S', 'Search a file by filename pattern matching.'],
			\ ['E', 'Open a explorer.exe. (Windows OS only)'],
			\ ['L', 'Open a file or a directory under the cursor.'],
			\ ['H', 'Go up to parent directory.'],
			\ ['C', 'Set the current directory to the dig''s directory.'],
			\ ['~', 'Change the current directory to Home directory.'],
			\ ['?', 'Print this help.'],
			\ ]
		for x in xs
			echohl Title
			echo ' ' .. x[0] .. ' key : '
			echohl None
			echon x[1]
		endfor
	endif
endfunction



function! s:open(rootdir, lines, is_driveletters, is_searchresult) abort
	if !empty(a:lines)
		let pattern = ''
		if &filetype == s:FILETYPE
			call dig#close()
		else
			let pattern = fnamemodify(bufname(), ':t')
		endif
		let t:dig = {
			\ 'prev_winid' : win_getid(),
			\ 'rootdir' : a:rootdir,
			\ 'is_driveletters' : a:is_driveletters,
			\ 'is_searchresult' : a:is_searchresult,
			\ }
		vnew
		let t:dig['dig_winid'] = win_getid()
		setlocal noreadonly modified nonumber
		silent! call deletebufline('%', 1, '$')
		call setbufline('%', 1, a:lines)
		let width = max(map(copy(a:lines), { _,x -> strdisplaywidth(x) })) + 1
		execute printf('vertical resize %d', width)
		setlocal buftype=nofile readonly nomodified nobuflisted
		let &l:filetype = s:FILETYPE
		call s:set_statusline()
		if !empty(pattern)
			call search('^' .. pattern .. '$')
			call feedkeys('zz', 'nx')
		endif
	else
		call dig#io#error(printf('There are no files or directories in "%s".', a:rootdir))
	endif
endfunction

function! s:set_statusline() abort
	let &l:statusline = printf('[%s] %%l/%%L ', s:FILETYPE)
endfunction

function! s:is_dig() abort
	call s:configure(v:false)
	return (t:dig['dig_winid'] == win_getid()) && (&filetype == s:FILETYPE)
endfunction

function! s:configure(force_init) abort
	if a:force_init
		let t:dig = {}
	else
		let t:dig = get(t:, 'dig', {})
	endif
	let t:dig['dig_winid'] = get(t:dig, 'dig_winid', -1)
	let t:dig['prev_winid'] = get(t:dig, 'prev_winid', -1)
	let t:dig['rootdir'] = get(t:dig, 'rootdir', '.')
	let t:dig['is_driveletters'] = get(t:dig, 'is_driveletters', v:false)
	let t:dig['is_searchresult'] = get(t:dig, 'is_searchresult', v:false)
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

