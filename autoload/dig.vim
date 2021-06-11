
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
		\ 'minwidth' : 40,
		\ 'minheight' : 5,
		\ 'maxheight' : 20,
		\ 'filter' : function('s:filter', [rootdir]),
		\ 'callback' : function('s:callback', [rootdir]),
		\ })
	call win_execute(winid, 'setfiletype ' .. s:FILETYPE)
endfunction

function! s:adjust_winheight() abort
	resize 10
	setlocal winfixheight
endfunction

function! s:filter(rootdir, winid, key) abort
	let n = char2nr(a:key)

	if char2nr('d') == n
		let toplevel = dig#git#rootdir(a:rootdir)
		if executable('git') && !empty(toplevel)
			try
				let lines = dig#git#diff(fnamemodify(a:rootdir, ':p'))
				if empty(lines)
					call dig#io#error('Not a git repository or no modified files.')
				else
					call popup_close(a:winid)
					call dig#window#new()
					call s:adjust_winheight()
					setlocal noreadonly modified nonumber
					silent! call deletebufline('%', 1, '$')
					call setbufline('%', 1, lines)
					setlocal buftype=nofile readonly nomodified nobuflisted
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
					execute printf('nnoremap <buffer><cr>   :<C-u>call dig#git#show_diff(%s, line("."))<cr>', string(toplevel))
				endif
			catch /^Vim:Interrupt$/
				let interrupts = v:true
			endtry
		endif
		return 1

	elseif char2nr('t') == n
		call popup_close(a:winid)
		call term_start(&shell, { 'cwd' : a:rootdir, 'term_finish' : 'close' })
		return 1

	elseif char2nr('e') == n
		if has('win32')
			call popup_close(a:winid)
			execute '!start ' .. fnamemodify(a:rootdir, ':p')
		endif
		return 1

	elseif char2nr('h') == n
		if !has('win32') || !empty(a:rootdir)
			call popup_close(a:winid)
			call dig#open(a:rootdir .. '/..')
		endif
		return 1

	elseif char2nr('l') == n
		return popup_filter_menu(a:winid, "\<cr>")

	else
		return popup_filter_menu(a:winid, a:key)

	endif
endfunction

function! s:callback(rootdir, winid, key) abort
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
			call dig#window#open(path, -1)
		endif
	endif
endfunction

