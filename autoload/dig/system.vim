
function! dig#system#system(cmd, toplevel) abort
	let xs = s:system(a:cmd, a:toplevel, v:false, v:false)
	for i in range(0, len(xs) - 1)
		if dig#sillyiconv#utf_8(xs[i])
			let xs[i] = s:iconv(xs[i], 'utf-8')
		else
			let xs[i] = s:iconv(xs[i], 'cp932')
		endif
	endfor
	return xs
endfunction

function! dig#system#system_for_git(cmd, toplevel, is_git_output) abort
	return s:system(a:cmd, a:toplevel, v:true, a:is_git_output)
endfunction



function! s:system(cmd, toplevel, for_git, is_git_output) abort
	let lines = []
	if exists('*job_start')
		let path = tempname()
		try
			let job = job_start(a:cmd, {
				\ 'cwd' : a:toplevel,
				\ 'out_io' : 'file',
				\ 'out_name' : path,
				\ })
			while 'run' == job_status(job)
			endwhile
			if filereadable(path)
				let lines = readfile(path)
			endif
		finally
			if filereadable(path)
				call delete(path)
			endif
		endtry
	else
		let saved = getcwd()
		try
			lcd `=a:toplevel`
			let lines = split(system(join(a:cmd)), "\n")
		finally
			lcd `=saved`
		endtry
	endif

	if a:for_git
		let enc_from = ''
		for i in range(0, len(lines) - 1)
			if a:is_git_output
				let lines[i] = s:iconv(lines[i], 'utf-8')
			else
				" The encoding of top 4 lines('diff -...', 'index ...', '--- a/...', '+++ b/...') is always utf-8.
				if i < 4
					let lines[i] = s:iconv(lines[i], 'utf-8')
				else
					" check if the line contains a multibyte-character.
					if 0 < len(filter(split(lines[i], '\zs'), {i,x -> 0x80 < char2nr(x) }))
						if empty(enc_from)
							if dig#sillyiconv#utf_8(lines[i])
								let enc_from = 'utf-8'
							else
								let enc_from = 'shift_jis'
							endif
						endif
						let lines[i] = s:iconv(lines[i], enc_from)
					endif
				endif
			endif
		endfor
	endif

	return lines
endfunction

function! s:iconv(text, from) abort
	if a:from != &encoding
		return iconv(a:text, a:from, &encoding)
	else
		return a:text
	endif
endfunction

