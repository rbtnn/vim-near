
let s:FILETYPE = 'near'

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
	let rootdir = near#io#fix_path(rootdir)
	let lines = near#io#readdir(rootdir)
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
		echohl Error
		echo printf('There are no files or directories in "%s".', a:rootdir)
		echohl None
	endif
endfunction

function! near#close() abort
	call s:configure(v:false)
	if (t:near['near_winid'] == win_getid()) && (&filetype == s:FILETYPE)
		" Does not close the Near window if here is CmdLineWindow.
		if ':' != getcmdtype()
			close
			if 0 < win_id2win(t:near['prev_winid'])
				execute printf('%dwincmd w', win_id2win(t:near['prev_winid']))
			endif
			call s:configure(v:true)
		endif
	endif
endfunction

function! near#select_file(line) abort
	call s:configure(v:false)
	if (t:near['near_winid'] == win_getid()) && (&filetype == s:FILETYPE)
		let path = near#io#fix_path((t:near['is_driveletters'] ? '' : (t:near['rootdir'] .. '/')) .. a:line)
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
	call s:configure(v:false)
	if !t:near['is_driveletters']
		let curdir = fnamemodify(t:near['rootdir'], ':p:h')
		if -1 != index(near#io#driveletters(), curdir)
			call s:open('', near#io#driveletters(), v:true)
			let pattern = curdir
		else
			let updir = fnamemodify(curdir, ':h')
			call near#open(updir)
			let pattern = fnamemodify(curdir, ':t') .. '/'
		endif
		call search('^' .. pattern .. '$')
		call feedkeys('zz', 'nx')
	endif
endfunction

function! near#change_dir() abort
	call s:configure(v:false)
	let rootdir = t:near['rootdir']
	let view = winsaveview()
	call near#close()
	lcd `=rootdir`
	call near#open(rootdir)
	call winrestview(view)
endfunction

function! near#explorer() abort
	if has('win32')
		call s:configure(v:false)
		let rootdir = fnamemodify(t:near['rootdir'], ':p')
		call near#close()
		execute '!start ' .. rootdir
	endif
endfunction

function! near#terminal() abort
	call s:configure(v:false)
	let rootdir = t:near['rootdir']
	call near#close()
	if has('nvim')
		new
		call termopen(&shell, { 'cwd' : rootdir })
		startinsert
	else
		call term_start(&shell, { 'cwd' : rootdir, 'term_finish' : 'close' })
	endif
endfunction

function! near#help() abort
	let xs = [
		\ ['Enter', 'Open a file or a directory under the cursor.'],
		\ ['Space', 'Open a file or a directory under the cursor.'],
		\ ['Esc', 'Close the Near window.'],
		\ ['T', 'Open a terminal window.'],
		\ ['E', 'Open a explorer.exe. (Windows OS only)'],
		\ ['L', 'Open a file or a directory under the cursor.'],
		\ ['H', 'Go up to parent directory.'],
		\ ['C', 'Change the current directory to the Near''s directory.'],
		\ ['~', 'Change the current directory to Home directory.'],
		\ ['?', 'Print this help.'],
		\ ]
	for x in xs
		echohl Title
		echo ' ' .. x[0] .. ' key : '
		echohl None
		echon x[1]
	endfor
endfunction



function! s:configure(force_init) abort
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

