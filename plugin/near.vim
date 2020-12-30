
let g:loaded_near = 1

command! -bar -nargs=0 Near :call <SID>near()

augroup near
	autocmd!
	autocmd WinLeave *     :call <SID>try_close()
	autocmd WinEnter *     :call <SID>restore_view()
augroup END

let g:near_ignoredirs = get(g:, 'near_ignoredirs', ['node_modules', '.git', '.svn', '_svn'])
let g:near_maxdepth = get(g:, 'near_maxdepth', 2)

function! s:near() abort
	if &filetype != 'near'
		let lines = s:readfiles('.', g:near_maxdepth)
		let width = max(map(copy(lines), { _,x -> strdisplaywidth(x) })) + 1
		let t:near = {
			\ 'prev_view' : winsaveview(),
			\ 'prev_winid' : win_getid(),
			\ }
		rightbelow vnew
		let t:near['near_winid'] = win_getid()
		call setbufline('%', 1, lines)
		execute printf('vertical resize %d', width)
		setlocal buftype=nofile readonly nomodified nobuflisted
		setlocal filetype=near statusline=[near]
		nnoremap <buffer><cr>   :<C-u>call <SID>open(getline('.'))<cr>
	endif
endfunction

function! s:try_close() abort
	let t:near = get(t:, 'near', {})
	if get(t:near, 'near_winid', -1) == win_getid()
		close
		execute printf('%dwincmd w', win_id2win(t:near['prev_winid']))
	endif
	" Because WinEnter event is not emited when Ctrl-w_c in a near window.
	call s:restore_view()
endfunction

function! s:restore_view() abort
	let t:near = get(t:, 'near', {})
	if (get(t:near, 'prev_winid', -1) == win_getid()) && !empty(get(t:near, 'prev_view', {}))
		call winrestview(get(t:near, 'prev_view', {}))
	endif
endfunction

function! s:open(line) abort
	let t:near = get(t:, 'near', {})
	if (get(t:near, 'near_winid', -1) == win_getid()) && filereadable(a:line)
		call s:try_close()
		execute printf('edit %s', escape(a:line, '\ '))
	endif
endfunction

function! s:readfiles(path, depth) abort
	let xs = []
	if 0 < a:depth
		try
			for name in readdir(a:path)
				let relpath = fnamemodify(a:path .. '/' .. name, ':.')
				if filereadable(relpath)
					let xs += [relpath]
				elseif isdirectory(relpath) && (-1 == index(g:near_ignoredirs, name))
					let xs += s:readfiles(relpath, a:depth - 1)
				endif
			endfor
		catch
			echohl Error
			echo v:exception
			echohl None
		endtry
	endif
	return xs
endfunction
