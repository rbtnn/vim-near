if !exists(':vim9script')
	finish
endif
vim9script

import * as sillyiconv from './sillyiconv.vim'

export def System(cmd: list<string>, cwd: string): list<string>
	var xs = s:system(cmd, cwd, v:false, v:false)
	for i in range(0, len(xs) - 1)
		if sillyiconv.IsUTF8(xs[i])
			xs[i] = s:iconv(xs[i], 'utf-8')
		else
			xs[i] = s:iconv(xs[i], 'cp932')
		endif
	endfor
	return xs
enddef

export def SystemForGit(cmd: list<string>, cwd: string, is_git_output: bool): list<string>
	return s:system(cmd, cwd, v:true, is_git_output)
enddef



def s:system(cmd: list<string>, cwd: string, for_git: bool, is_git_output: bool): list<string>
	var lines: list<string> = []
	if exists('*job_start')
		var path: string = tempname()
		try
			var job: job = job_start(cmd, {
				'cwd': cwd,
				'out_io': 'file',
				'out_name': path,
				})
			while 'run' == job_status(job)
			endwhile
			if filereadable(path)
				lines = readfile(path)
			endif
		finally
			if filereadable(path)
				delete(path)
			endif
		endtry
	else
		var saved: string = getcwd()
		try
			lcd `=cwd`
			lines = split(system(join(cmd)), "\n")
		finally
			lcd `=saved`
		endtry
	endif

	if for_git
		var enc_from: string = ''
		for i in range(0, len(lines) - 1)
			if is_git_output
				lines[i] = s:iconv(lines[i], 'utf-8')
			else
				# The encoding of top 4 lines('diff -...', 'index ...', '--- a/...', '+++ b/...') is always utf-8.
				if i < 4
					lines[i] = s:iconv(lines[i], 'utf-8')
				else
					# check if the line contains a multibyte-character.
					if 0 < len(filter(split(lines[i], '\zs'), (_, x) => 0x80 < char2nr(x)))
						if empty(enc_from)
							if sillyiconv.IsUTF8(lines[i])
								enc_from = 'utf-8'
							else
								enc_from = 'shift_jis'
							endif
						endif
						lines[i] = s:iconv(lines[i], enc_from)
					endif
				endif
			endif
		endfor
	endif

	return lines
enddef

def s:iconv(text: string, from: string): string
	if from != &encoding
		return iconv(text, from, &encoding)
	else
		return text
	endif
enddef

