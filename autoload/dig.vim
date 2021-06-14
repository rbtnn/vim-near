
let s:FILETYPE = 'dig'

function! dig#open(q_args) abort
	if empty(a:q_args)
		if isdirectory(expand('%:h'))
			let rootdir = expand('%:h')
		else
			let rootdir = '.'
		endif
	elseif isdirectory(a:q_args)
		let rootdir = a:q_args
	else
		let rootdir = '.'
	endif
	let rootdir = dig#io#fix_path(fnamemodify(rootdir, ':p'))

	if has('win32') && (rootdir =~# '^[A-Z]:/\+\.\./$')
		let lines = dig#io#driveletters()
		let rootdir = ''
	else
		let lines = dig#io#readdir(rootdir)
	endif

	let winid = popup_menu(lines, {
		\ 'padding' : [],
		\ 'minwidth' : 40,
		\ 'minheight' : 5,
		\ 'maxheight' : 20,
		\ })

	call s:file_setopts(winid, rootdir)

	call win_execute(winid, 'setfiletype ' .. s:FILETYPE)

	let i = index(lines, expand('%:t'))
	if -1 != i
		call win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', i + 1))
		call win_execute(winid, 'redraw')
	endif
endfunction



function! s:file_setopts(winid, rootdir) abort
	call popup_setoptions(a:winid, {
		\ 'title' : s:FILETYPE .. '(file)',
		\ 'filter' : function('s:file_filter', [(a:rootdir)]),
		\ 'callback' : function('s:file_callback', [(a:rootdir)]),
		\ })
endfunction

function! s:file_filter(rootdir, winid, key) abort
	if char2nr('d') == char2nr(a:key)
		let toplevel = dig#git#rootdir(a:rootdir)
		if !executable('git')
			call dig#io#error('git is not executable')
		elseif empty(toplevel)
			call dig#io#error('Not a git repository')
		else
			try
				let lines = dig#git#diff(fnamemodify(a:rootdir, ':p'))
				if empty(lines)
					call dig#io#error('No modified files.')
				else
					call popup_settext(a:winid, lines)
					call win_execute(a:winid, 'redraw')
					call s:diff_setopts(a:winid, a:rootdir)
				endif
			catch /^Vim:Interrupt$/
				" nop
			endtry
		endif
		return 1

	elseif char2nr('~') == char2nr(a:key)
		call popup_close(a:winid)
		call dig#open(expand('~'))
		return 1

	elseif char2nr('g') == char2nr(a:key)
		call win_execute(a:winid, printf('call setpos(".", [0, %d, 1, 0])', 1))
		call win_execute(a:winid, 'redraw')
		return 1

	elseif char2nr('G') == char2nr(a:key)
		call win_execute(a:winid, printf('call setpos(".", [0, %d, 1, 0])', line('$', a:winid)))
		call win_execute(a:winid, 'redraw')
		return 1

	elseif char2nr('t') == char2nr(a:key)
		call popup_close(a:winid)
		call term_start(&shell, { 'cwd' : a:rootdir, 'term_finish' : 'close' })
		return 1

	elseif char2nr('c') == char2nr(a:key)
		lcd `=a:rootdir`
		echohl Title
		echo printf('Change the current directory to "%s" in the current window.', getcwd())
		echohl None
		return 1

	elseif char2nr('e') == char2nr(a:key)
		if has('win32')
			call popup_close(a:winid)
			execute '!start ' .. fnamemodify(a:rootdir, ':p')
		else
			call dig#io#error('error')
		endif
		return 1

	elseif char2nr('h') == char2nr(a:key)
		if !has('win32') || !empty(a:rootdir)
			call popup_close(a:winid)
			call dig#open(a:rootdir .. '/..')
		endif
		return 1

	elseif char2nr('l') == char2nr(a:key)
		return popup_filter_menu(a:winid, "\<cr>")

	else
		return popup_filter_menu(a:winid, a:key)

	endif
endfunction

function! s:file_callback(rootdir, winid, key) abort
	let lines = getbufline(winbufnr(a:winid), 1, '$')
	if 0 < a:key
		if empty(a:rootdir)
			let path = lines[(a:key - 1)]
		else
			let path = a:rootdir .. '/' .. lines[(a:key - 1)]
		endif
		if isdirectory(path)
			call dig#open(path)
		elseif filereadable(path)
			if &modified
				call dig#io#error('the current buffer is modified.')
			else
				call dig#window#open(path, -1)
			endif
		endif
	endif
endfunction



function! s:diff_setopts(winid, rootdir) abort
	call popup_setoptions(a:winid, {
		\ 'title' : s:FILETYPE .. '(git-diff)',
		\ 'filter' : function('s:diff_filter', [(a:rootdir)]),
		\ 'callback' : function('s:diff_callback', [(a:rootdir)]),
		\ })
endfunction

function! s:diff_filter(rootdir, winid, key) abort
	if char2nr('h') == char2nr(a:key)
		call popup_close(a:winid)
		call dig#open(a:rootdir)
		return 1

	elseif char2nr('l') == char2nr(a:key)
		return popup_filter_menu(a:winid, "\<cr>")

	else
		return popup_filter_menu(a:winid, a:key)
	endif
endfunction

function! s:diff_callback(rootdir, winid, key) abort
	if 0 < a:key
		call dig#git#show_diff(a:rootdir, a:key)
	endif
endfunction

