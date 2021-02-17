
function! near#io#driveletters() abort
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

function! near#io#fix_path(path) abort
	return substitute(a:path, '[\/]\+', '/', 'g')
endfunction

function! near#io#readdir(path) abort
	let xs = []
	let rootdir = a:path
	if !empty(rootdir) && ('/' != split(rootdir, '\zs')[-1])
		let rootdir = rootdir .. '/'
	endif
	for name in s:readdir(rootdir)
		let relpath = near#io#fix_path(a:path .. '/' .. name)
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

function! s:readdir(path) abort
	let xs = []
	try
		if exists('*readdir')
			let xs = readdir(a:path)
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

