if !exists(':vim9script')
	finish
endif
vim9script

import * as gitdiff from './gitdiff.vim'
import * as utils from './utils.vim'

const FILETYPE = 'dig'

export def OpenDigWindow(q_args: string)
	var rootdir: string
	var lines: list<string>

	if empty(q_args)
		if isdirectory(expand('%:h'))
			rootdir = expand('%:h')
		else
			rootdir = '.'
		endif
	elseif isdirectory(q_args)
		rootdir = q_args
	else
		rootdir = '.'
	endif
	rootdir = utils.FixPath(fnamemodify(rootdir, ':p'))

	if has('win32') && (rootdir =~# '^[A-Z]:/\+\.\./$')
		lines = utils.GetDriveLetters()
		rootdir = ''
	else
		lines = utils.ReadDir(rootdir)
	endif

	var winid: number = popup_menu(lines, {
		'padding': [],
		'minwidth': 40,
		'minheight': 5,
		'maxheight': 20,
		})

	s:file_setopts(winid, rootdir)

	win_execute(winid, 'setfiletype ' .. FILETYPE)

	var i = index(lines, expand('%:t'))
	if -1 != i
		win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', i + 1))
		win_execute(winid, 'redraw')
	endif
enddef



def s:file_setopts(winid: number, rootdir: string)
	popup_setoptions(winid, {
		'title': FILETYPE .. '(file)',
		'filter': function('s:file_filter', [rootdir]),
		'callback': function('s:file_callback', [rootdir]),
		})
enddef

def s:file_filter(rootdir: string, winid: number, key: string): bool
	if char2nr('d') == char2nr(key)
		var toplevel: string = gitdiff.GetRootDir(rootdir)
		if !executable('git')
			utils.ErrorMsg('git is not executable')
		elseif empty(toplevel)
			utils.ErrorMsg('Not a git repository')
		else
			try
				var lines: list<string> = gitdiff.Exec(fnamemodify(rootdir, ':p'))
				if empty(lines)
					utils.ErrorMsg('No modified files.')
				else
					popup_settext(winid, lines)
					win_execute(winid, 'redraw')
					s:diff_setopts(winid, rootdir)
				endif
			catch /^Vim:Interrupt$/
				# nop
			endtry
		endif
		return v:true

	elseif char2nr('~') == char2nr(key)
		popup_close(winid)
		OpenDigWindow(expand('~'))
		return v:true

	elseif char2nr('g') == char2nr(key)
		win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', 1))
		win_execute(winid, 'redraw')
		return v:true

	elseif char2nr('G') == char2nr(key)
		win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', line('$', winid)))
		win_execute(winid, 'redraw')
		return v:true

	elseif char2nr('t') == char2nr(key)
		popup_close(winid)
		term_start(&shell, { 'cwd': rootdir, 'term_finish': 'close' })
		return v:true

	elseif char2nr('c') == char2nr(key)
		lcd `=rootdir`
		utils.TitleMsg(printf('Change the current directory to "%s" in the current window.', getcwd()))
		return v:true

	elseif char2nr('e') == char2nr(key)
		if has('win32')
			popup_close(winid)
			execute '!start ' .. fnamemodify(rootdir, ':p')
		else
			utils.ErrorMsg('error')
		endif
		return v:true

	elseif char2nr('h') == char2nr(key)
		if !has('win32') || !empty(rootdir)
			popup_close(winid)
			OpenDigWindow(rootdir .. '/..')
		endif
		return v:true

	elseif char2nr('l') == char2nr(key)
		return popup_filter_menu(winid, "\<cr>")

	else
		return popup_filter_menu(winid, key)

	endif
enddef

def s:file_callback(rootdir: string, winid: number, lnum: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < lnum
		var path: string = (empty(rootdir) ? '' : rootdir .. '/') ..  lines[lnum - 1]
		if isdirectory(path)
			OpenDigWindow(path)
		elseif filereadable(path)
			if &modified
				utils.ErrorMsg('the current buffer is modified.')
			else
				utils.OpenFile(path, -1)
			endif
		endif
	endif
enddef



def s:diff_setopts(winid: number, rootdir: string)
	popup_setoptions(winid, {
		'title': FILETYPE .. '(git-diff)',
		'filter': function('s:diff_filter', [rootdir]),
		'callback': function('s:diff_callback', [rootdir]),
		})
enddef

def s:diff_filter(rootdir: string, winid: number, key: string): bool
	if char2nr('h') == char2nr(key)
		popup_close(winid)
		OpenDigWindow(rootdir)
		return v:true

	elseif char2nr('l') == char2nr(key)
		return popup_filter_menu(winid, "\<cr>")

	else
		return popup_filter_menu(winid, key)
	endif
enddef

def s:diff_callback(rootdir: string, winid: number, lnum: number)
	if 0 < lnum
		gitdiff.ShowDiff(rootdir, lnum)
	endif
enddef

