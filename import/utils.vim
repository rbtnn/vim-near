if !exists(':vim9script')
	finish
endif
vim9script

import * as sys from './sys.vim'

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

export def ErrorMsg(text: string)
	popup_notification(text, {
		'pos': 'center',
		'time': 1000,
		'highlight': 'Error',
		})
enddef

export def TitleMsg(text: string)
	popup_notification(text, {
		'pos': 'center',
		'time': 1000,
		'highlight': 'Title',
		})
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

export def NewWindow()
	new
enddef

export def FindWindowByFiletype(ft: string): bool
	for n in range(1, winnr('$'))
		if ft == getwinvar(n, '&filetype', '')
			execute printf(':%dwincmd w', n)
			return v:true
		endif
	endfor
	return v:false
enddef

export def FindWindowByPath(path: string): bool
	for x in filter(getwininfo(), (_, x) => x['tabnr'] == tabpagenr())
		if x['bufnr'] == s:strict_bufnr(path)
			execute printf(':%dwincmd w', x['winnr'])
			return v:true
		endif
	endfor
	return v:false
enddef

export def OpenFile(path: string, lnum: number)
	var bnr: number = s:strict_bufnr(path)
	if -1 == bnr
		execute printf('edit %s', fnameescape(path))
	else
		execute printf('buffer %d', bnr)
	endif
	if 0 < lnum
		execute printf(':%d', lnum)
	endif
enddef



def s:strict_bufnr(path: string): number
	var bnr: number = bufnr(path)
	var fname1: string = fnamemodify(path, ':t')
	var fname2: string = fnamemodify(bufname(bnr), ':t')
	if (-1 == bnr) || (fname1 != fname2)
		return -1
	else
		return bnr
	endif
enddef

def s:readdir(path: string): list<string>
	var xs: list<string> = []
	try
		if has('win32')
			xs = sys.System(['cmd', '/c', 'dir /a-s /b'], path)
		else
			silent! xs = readdir(path)
		endif
	catch /^Vim\%((\a\+)\)\=:E484:/
		# skip the directory.
		# E484: Can't open file ...
	endtry
	return xs
enddef

