vim9script

export def GetDriveLetters(): list<string>
	var xs: list<string> = []
	if has('win32')
		for n in range(char2nr('A'), char2nr('Z'))
			if isdirectory(nr2char(n) .. ':')
				xs += [nr2char(n) .. ':/']
			endif
		endfor
	endif
	return xs
enddef

export def Error(text: string)
	echohl Error
	echo text
	echohl None
enddef

export def FixPath(path: string): string
	return substitute(path, '[\/]\+', '/', 'g')
enddef

export def ReadDir(path: string): list<string>
	var xs: list<string> = s:readdir(path)
	filter(xs, (_, x) => !empty(expand(path .. '/' .. x)))
	map(xs, (_, x) => isdirectory(path .. '/' .. x) ? x .. '/' : x)
	return xs
enddef



def s:readdir(path: string): list<string>
	var xs: list<string> = []
	try
		if has('win32')
			xs = dig#system#system('cmd /c "dir /a-s /b"', path)
		else
			silent! xs = readdir(path)
		endif
	catch /^Vim\%((\a\+)\)\=:E484:/
		# skip the directory.
		# E484: Can't open file ...
	endtry
	return xs
enddef

