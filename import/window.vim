vim9script

export def New()
	new
enddef

export def FindByFiletype(ft: string): bool
	for n in range(1, winnr('$'))
		if ft == getwinvar(n, '&filetype', '')
			execute printf(':%dwincmd w', n)
			return v:true
		endif
	endfor
	return v:false
enddef

export def FindByPath(path: string): bool
	for x in filter(getwininfo(), (_, x) => x['tabnr'] == tabpagenr())
		if x['bufnr'] == s:strict_bufnr(path)
			execute printf(':%dwincmd w', x['winnr'])
			return v:true
		endif
	endfor
	return v:false
enddef

export def Open(path: string, lnum: number)
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

