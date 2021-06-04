
function! dig#window#new() abort
	belowright new
endfunction

function! dig#window#find_filetype(ft) abort
	for n in range(1, winnr('$'))
		if a:ft == getwinvar(n, '&filetype', '')
			execute n .. 'wincmd w'
			return v:true
		endif
	endfor
	return v:false
endfunction

function! dig#window#find_path(path) abort
	for x in filter(getwininfo(), { _, x -> x['tabnr'] == tabpagenr() })
		if x['bufnr'] == s:strict_bufnr(a:path)
			execute x['winnr'] .. 'wincmd w'
			return v:true
		endif
	endfor
	return v:false
endfunction

function! dig#window#open(path, lnum) abort
	let bnr = s:strict_bufnr(a:path)
	if -1 == bnr
		execute printf('edit %s', fnameescape(a:path))
	else
		execute printf('buffer %d', bnr)
	endif
	if 0 < a:lnum
		execute printf('%d', a:lnum)
	endif
endfunction



function! s:strict_bufnr(path) abort
	let bnr = bufnr(a:path)
	let fname1 = fnamemodify(a:path, ':t')
	let fname2 = fnamemodify(bufname(bnr), ':t')
	if (-1 == bnr) || (fname1 != fname2)
		return -1
	else
		return bnr
	endif
endfunction

