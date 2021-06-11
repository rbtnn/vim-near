
function! dig#io#driveletters() abort
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

function! dig#io#error(text) abort
	echohl Error
	echo a:text
	echohl None
endfunction

function! dig#io#fix_path(path) abort
	return substitute(a:path, '[\/]\+', '/', 'g')
endfunction

function! dig#io#readdir(path) abort
	let xs = s:readdir(a:path)
	call filter(xs, { i,x -> !empty(expand(a:path .. '/' .. x)) })
	call map(xs, { i,x -> isdirectory(a:path .. '/' .. x) ? x .. '/' : x })
	return xs
endfunction

function! s:readdir(path) abort
	let xs = []
	try
		if exists('*readdir')
			silent! let xs = readdir(a:path)
		else
			let saved = getcwd()
			try
				lcd `=a:path`
				let xs = split(glob('.*') .. "\n" .. glob('*'), "\n")
				call filter(xs, { _,x -> (x != '.') && (x != '..') })
			finally
				lcd `=saved`
			endtry
		endif
	catch /^Vim\%((\a\+)\)\=:E484:/
		" skip the directory.
		" E484: Can't open file ...
	endtry
	return xs
endfunction

