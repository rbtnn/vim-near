if !exists(':vim9script')
	finish
endif
vim9script

import * as sys from './sys.vim'
import * as utils from './utils.vim'

const NUMSTAT_HEAD = 12

var s:info_caches = get(s:, 'info_caches', {})
var s:keys_caches = get(s:, 'keys_caches', {})
var s:args_caches = get(s:, 'args_caches', {})

export def ExecDiff(path: string, input: string): list<string>
	var toplevel: string = GetRootDir(path)
	if isdirectory(toplevel)
		var args: list<string> = split(input, '\s\+')
		redraw
		var dict = {}
		var cmd: list<string> = ['git', '--no-pager', 'diff', '--numstat'] + args
		for line in sys.SystemForGit(cmd, toplevel, v:true)
			var m = matchlist(line, '^\s*\(\d\+\)\s\+\(\d\+\)\s\+\(.*\)$')
			if !empty(m)
				var key = m[3]
				if !has_key(dict, key)
					dict[key] = {
							'additions': m[1],
							'deletions': m[2],
							'name': key,
							'fullpath': s:expand2fullpath(toplevel .. '/' .. key),
						}
				endif
			endif
		endfor
		var ks: list<string> = sort(keys(dict))
		var lines: list<string> = map(deepcopy(ks), (i, key) =>
			printf('%5s %5s %s',
			'+' .. dict[key]['additions'],
			'-' .. dict[key]['deletions'],
			dict[key]['name'])
			)
		s:args_caches[toplevel] = args
		s:info_caches[toplevel] = dict
		s:keys_caches[toplevel] = ks
		return lines
	else
		return []
	endif
enddef

export def ExecLs(path: string, input: string): list<string>
	if isdirectory(path)
		var args: list<string> = split(input, '\s\+')
		var cmd: list<string> = ['git', '--no-pager', 'ls'] + args
		return sys.SystemForGit(cmd, path, v:true)
	else
		return []
	endif
enddef

export def ExecGrep(path: string, input: string): list<string>
	if isdirectory(path)
		var cmd: list<string> = ['git', '--no-pager', 'grep', '-I', '--no-color', '-n', input]
		return sys.SystemForGit(cmd, path, v:true)
	else
		return []
	endif
enddef

export def ShowDiff(rootdir: string, lnum: number)
	var toplevel: string = GetRootDir(rootdir)
	var key: string = s:keys_caches[toplevel][(lnum - 1)]
	var fullpath: string = s:info_caches[toplevel][key]['fullpath']
	var args: list<string> = s:args_caches[toplevel]
	var cmd: list<string> = s:build_cmd(args, fullpath)
	s:new_diff_window(sys.SystemForGit(cmd, toplevel, v:false), cmd)
	execute printf('nnoremap <buffer><silent><nowait><cr>       :<C-w>call <SID>jump_diff(%s)<cr>', string(fullpath))
	execute printf('nnoremap <buffer><silent><nowait>R          :<C-w>call <SID>rediff(%s, %s, %s)<cr>', string(toplevel), string(args), string(fullpath))
enddef

export def GetRootDir(path: string): string
	var xs: list<string> = split(path, '[\/]')
	var prefix: string = (has('mac') || has('linux')) ? '/' : ''
	while !empty(xs)
		if isdirectory(prefix .. join(xs + ['.git'], '/'))
			return s:expand2fullpath(prefix .. join(xs, '/'))
		endif
		remove(xs, -1)
	endwhile
	return ''
enddef



def s:expand2fullpath(path: string): string
	return utils.FixPath(resolve(fnamemodify(path, ':p')))
enddef

def s:build_cmd(args: list<string>, fullpath: string): list<string>
	return ['git', '--no-pager', 'diff'] + args + ['--', fullpath]
enddef

def s:rediff(toplevel: string, args: list<string>, fullpath: string)
	var view: dict<any> = winsaveview()
	var cmd: list<string> = s:build_cmd(args, fullpath)
	call s:new_diff_window(sys.SystemForGit(cmd, toplevel, v:false), cmd)
	call winrestview(view)
enddef

def s:new_diff_window(lines: list<string>, cmd: list<string>)
	if !utils.FindWindowByFiletype('diff')
		utils.NewWindow()
	endif
	setlocal noreadonly modifiable
	silent! call deletebufline('%', 1, '$')
	setbufline('%', 1, lines)
	setlocal readonly nomodifiable buftype=nofile nocursorline
	&l:filetype = 'diff'
	&l:statusline = join(cmd)
enddef

def s:jump_diff(fullpath: string)
	var ok: bool = v:false
	var lnum: number = search('^@@', 'bnW')
	if 0 < lnum
		var n1: number = 0
		var n2: number = 0
		for n in range(lnum + 1, line('.'))
			var line: string = getline(n)
			if line =~# '^-'
				n2 += 1
			elseif line =~# '^+'
				n1 += 1
			endif
		endfor
		var n3: number = line('.') - lnum - n1 - n2 - 1
		var m: list<string> = []
		var m2: list<string> = matchlist(getline(lnum), '^@@ \([+-]\)\(\d\+\)\%(,\d\+\)\? \([+-]\)\(\d\+\)\%(,\d\+\)\?\s*@@\(.*\)$')
		var m3: list<string> = matchlist(getline(lnum), '^@@@ \([+-]\)\(\d\+\)\%(,\d\+\)\? \([+-]\)\(\d\+\)\%(,\d\+\)\? \([+-]\)\(\d\+\),\d\+\s*@@@\(.*\)$')
		if !empty(m2)
			m = m2
		elseif !empty(m3)
			m = m3
		endif
		if !empty(m)
			for i in [1, 3, 5]
				if '+' == m[i]
					if filereadable(fullpath)
						lnum = str2nr(m[i + 1]) + n1 + n3
						if utils.FindWindowByPath(fullpath)
							execute printf(':%d', lnum)
						else
							utils.NewWindow()
							utils.OpenFile(fullpath, lnum)
						endif
						silent! foldopen!
						normal! zz
					endif
					ok = v:true
					break
				endif
			endfor
		endif
	endif
	if !ok
		utils.ErrorMsg('Can not jump this!')
	endif
enddef

