
function! near#io#search(path, pattern, maxdepth) abort
	let xs = []
	let interrupts = v:false
	if 0 < a:maxdepth
		try
			for fname in s:readdir(a:path)
				let abspath = near#io#fix_path(a:path .. '/' .. fname)
				if s:is_ignore(abspath)
					continue
				endif
				if filereadable(abspath)
					if fname =~# a:pattern
						let xs += [abspath]
					endif
				elseif isdirectory(abspath)
					let dict = near#io#search(abspath, a:pattern, a:maxdepth - 1)
					let xs += dict['xs']
					if dict['interrupts']
						let interrupts = v:true
						break
					endif
				endif
			endfor
		catch /^Vim:Interrupt$/
			let interrupts = v:true
		endtry
	endif
	return { 'xs' : xs, 'interrupts' : interrupts }
endfunction

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

function! near#io#error(text) abort
	echohl Error
	echo a:text
	echohl None
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
	for fname in s:readdir(rootdir)
		let relpath = near#io#fix_path(rootdir .. fname)
		if s:is_ignore(relpath)
			continue
		endif
		if filereadable(relpath)
			if rootdir == relpath[:len(rootdir) - 1]
				let xs += [relpath[len(rootdir):]]
			else
				let xs += [relpath]
			endif
		elseif isdirectory(relpath) && (fnamemodify(fname, ':t') !~# '^\$')
			if rootdir == relpath[:len(rootdir) - 1]
				let xs += [relpath[len(rootdir):] .. '/']
			else
				let xs += [relpath .. '/']
			endif
		endif
	endfor
	return xs
endfunction

function! s:is_ignore(path) abort
	return empty(expand(a:path))
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

