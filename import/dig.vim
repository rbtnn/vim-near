if !exists(':vim9script')
	finish
endif
vim9script

import * as gitdiff from './gitdiff.vim'
import * as utils from './utils.vim'

const TYPE_FILE = 'dig(file)'
const TYPE_DIFF = 'dig(diff)'

export def OpenDigWindow(q_args: string)
	var rootdir: string = utils.FixPath(fnamemodify(expand(q_args), ':p'))
	var lines: list<string>
	var reload: bool = empty(get(t:, 'dig_params', {})) || !empty(q_args)

	if !isdirectory(rootdir)
		return
	endif

	if reload
		t:dig_params = {}
		if has('win32') && (rootdir =~# '^[A-Z]:/\+\.\./\?$')
			rootdir = ''
			lines = utils.GetDriveLetters()
		else
			lines = utils.ReadDir(rootdir)
		endif
	endif

	var winid: number = popup_menu([], {
		'padding': [],
		'minwidth': 40,
		'minheight': 5,
		'maxheight': 20,
		})
	win_execute(winid, 'setfiletype dig')

	if reload
		s:setopts(TYPE_FILE, winid, rootdir, lines)
	else
		s:setopts(t:dig_params['type'], winid, t:dig_params['rootdir'], t:dig_params['lines'])
	endif

	var i = index(t:dig_params['lines'], expand('%:t'))
	if -1 != i
		win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', i + 1))
		win_execute(winid, 'redraw')
	endif
enddef



def s:setopts(type: string, winid: number, rootdir: string, lines: list<string>)
	if type == TYPE_FILE
		popup_setoptions(winid, {
			'title': TYPE_FILE,
			'filter': function('s:file_filter', [rootdir]),
			'callback': function('s:file_callback', [rootdir]),
			})
	else
		popup_setoptions(winid, {
			'title': TYPE_DIFF,
			'filter': function('s:diff_filter', [rootdir]),
			'callback': function('s:diff_callback', [rootdir]),
			})
	endif
	popup_settext(winid, lines)
	win_execute(winid, 'redraw')
	t:dig_params = {
		'type': type,
		'rootdir': rootdir,
		'lines': lines,
		}
	echo rootdir
enddef



def s:common_filter(rootdir: string, winid: number, key: string): list<bool>
	if char2nr('g') == char2nr(key)
		win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', 1))
		win_execute(winid, 'redraw')
		return [(v:true)]

	elseif char2nr('G') == char2nr(key)
		win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', line('$', winid)))
		win_execute(winid, 'redraw')
		return [(v:true)]

	elseif char2nr('t') == char2nr(key)
		popup_close(winid)
		term_start(&shell, { 'cwd': rootdir, 'term_finish': 'close' })
		return [(v:true)]

	elseif char2nr('l') == char2nr(key)
		return [popup_filter_menu(winid, "\<cr>")]

	elseif char2nr('h') == char2nr(key)
		if !has('win32') || !empty(rootdir)
			popup_close(winid)
			OpenDigWindow(rootdir .. '/..')
		endif
		return [(v:true)]

	else
		return []
	endif
enddef



def s:file_filter(rootdir: string, winid: number, key: string): bool
	var m = s:common_filter(rootdir, winid, key)
	if !empty(m)
		return m[0]
	else
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
						s:setopts(TYPE_DIFF, winid, rootdir, lines)
					endif
				catch /^Vim:Interrupt$/
					# nop
				endtry
			endif
			return v:true

		elseif char2nr('r') == char2nr(key)
			var toplevel: string = gitdiff.GetRootDir(rootdir)
			if empty(toplevel)
				utils.ErrorMsg('Not a git repository')
			else
				popup_close(winid)
				OpenDigWindow(toplevel)
			endif
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

		else
			return popup_filter_menu(winid, key)

		endif
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



def s:diff_filter(rootdir: string, winid: number, key: string): bool
	var m = s:common_filter(rootdir, winid, key)
	if !empty(m)
		return m[0]
	else
		return popup_filter_menu(winid, key)
	endif
enddef

def s:diff_callback(rootdir: string, winid: number, lnum: number)
	if 0 < lnum
		gitdiff.ShowDiff(rootdir, lnum)
	endif
enddef

