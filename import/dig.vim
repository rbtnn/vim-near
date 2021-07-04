if !exists(':vim9script')
	finish
endif
vim9script
scriptencoding utf-8

import * as gitdiff from './gitdiff.vim'
import * as utils from './utils.vim'

const TYPE_FILE = 'file'
const TYPE_DIFF = 'diff'
const FOLDER_ICON = '📁'

export def OpenDigWindow(q_args: string, cursor_text: string = '')
	var rootdir: string = utils.FixPath(fnamemodify(expand(q_args), ':p'))
	var reload: bool = empty(get(t:, 'dig_params', {})) || !empty(q_args)
	var lines: list<string>

	if !isdirectory(rootdir)
		return
	endif

	var winid: number = popup_menu([], {
			'border': [1, 0, 0, 0],
			'borderchars': repeat([' '], 8),
			'padding': [0, 1, 0, 1],
			'borderhighlight': ['digTitle'],
			'scrollbarhighlight': 'digScrollbar',
			'thumbhighlight': 'digThumb',
			'minwidth': &columns / 2,
			'minheight': 20,
			'maxheight': 20,
		})
	win_execute(winid, 'setfiletype dig')

	if reload
		t:dig_params = {}
		if has('win32') && (rootdir =~# '^[A-Z]:/\+\.\./\?$')
			rootdir = ''
			lines = utils.GetDriveLetters()
		else
			lines = utils.ReadDir(rootdir, FOLDER_ICON)
		endif
		s:setopts(TYPE_FILE, winid, rootdir, lines, 1, '')
		if !empty(cursor_text)
			var i = index(t:dig_params['lines'], cursor_text)
			if -1 != i
				s:set_lnum(winid, i + 1)
			endif
		endif
	else
		s:setopts(t:dig_params['type'], winid, t:dig_params['rootdir'], t:dig_params['lines'], t:dig_params['lnum'], t:dig_params['filter_text'])
	endif
enddef



def s:setopts(type: string, winid: number, rootdir: string, lines: list<string>, lnum: number, filter_text: string)
	clearmatches(winid)
	var filtered_lines: list<string>
	if !empty(filter_text)
		for line in lines
			# use ignorecase
			if line =~? filter_text
				filtered_lines += [line]
			endif
		endfor
		win_execute(winid, printf("matchadd('Search', %s)", string(filter_text)))
		popup_settext(winid, filtered_lines)
		s:set_lnum(winid, 1)
	else
		popup_settext(winid, lines)
		s:set_lnum(winid, lnum)
	endif
	t:dig_params = {
			'type': type,
			'rootdir': rootdir,
			'lines': lines,
			'lnum': lnum,
			'filter_text': filter_text,
		}
	var filtered_count = !empty(filter_text) ? printf('(%d/%d)', len(filtered_lines), len(lines)) : ''
	if type == TYPE_FILE
		popup_setoptions(winid, {
				'title': printf('[%s%s] %s', type, filtered_count, utils.FixPath(fnamemodify(rootdir, ':~'))),
				'filter': function('s:file_filter', [rootdir]),
				'callback': function('s:file_callback', [rootdir]),
			})
	else
		popup_setoptions(winid, {
				'title': printf('[%s%s] %s', type, filtered_count, utils.FixPath(fnamemodify(rootdir, ':~'))),
				'filter': function('s:diff_filter', [rootdir]),
				'callback': function('s:diff_callback', [rootdir]),
			})
	endif
enddef

def s:set_lnum(winid: number, lnum: number)
	win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', lnum))
	win_execute(winid, 'redraw')
enddef

def s:common_filter(rootdir: string, winid: number, key: string): list<bool>
	if char2nr('g') == char2nr(key)
		s:set_lnum(winid, 1)
		return [(v:true)]

	elseif char2nr('G') == char2nr(key)
		s:set_lnum(winid, line('$', winid))
		return [(v:true)]

	elseif char2nr('/') == char2nr(key)
		if has('gui_running')
			t:dig_params['filter_text'] = inputdialog('filter', get(t:dig_params, 'filter_text', ''))
		else
			t:dig_params['filter_text'] = input('filter>', get(t:dig_params, 'filter_text', ''))
		endif
		s:setopts(t:dig_params['type'], winid, t:dig_params['rootdir'], t:dig_params['lines'], t:dig_params['lnum'], t:dig_params['filter_text'])
		return [(v:true)]

	elseif char2nr('.') == char2nr(key)
		popup_close(winid)
		OpenDigWindow('.')
		return [(v:true)]

	elseif char2nr('~') == char2nr(key)
		popup_close(winid)
		OpenDigWindow('~')
		return [(v:true)]

	elseif char2nr('t') == char2nr(key)
		if !empty(rootdir)
			popup_close(winid)
			term_start(&shell, { 'cwd': rootdir, 'term_finish': 'close' })
		endif
		return [(v:true)]

	elseif char2nr('l') == char2nr(key)
		return [popup_filter_menu(winid, "\<cr>")]

	else
		return []
	endif
enddef

def s:file_filter(rootdir: string, winid: number, key: string): bool
	t:dig_params['lnum'] = line('.', winid)
	var m = s:common_filter(rootdir, winid, key)
	if !empty(m)
		return m[0]
	else
		if char2nr('d') == char2nr(key)
			var toplevel: string = gitdiff.GetRootDir(rootdir)
			if !executable('git')
				utils.ErrorMsg('git is not executable.')
			elseif empty(toplevel)
				utils.ErrorMsg('Current directory is not a git repository.')
			else
				try
					var lines: list<string> = gitdiff.Exec(fnamemodify(rootdir, ':p'))
					if empty(lines)
						utils.ErrorMsg('There are no modified files.')
					else
						s:setopts(TYPE_DIFF, winid, rootdir, lines, 1, '')
					endif
				catch /^Vim:Interrupt$/
					# nop
				endtry
			endif
			return v:true

		elseif char2nr('r') == char2nr(key)
			var toplevel: string = gitdiff.GetRootDir(rootdir)
			if empty(toplevel)
				utils.ErrorMsg('Current directory is not a git repository.')
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
				execute '!start ' .. fnamemodify(rootdir, ':p')
			else
				utils.ErrorMsg('Your OS is not Windows.')
			endif
			return v:true

		elseif char2nr('h') == char2nr(key)
			if !has('win32') || !empty(rootdir)
				popup_close(winid)
				OpenDigWindow(rootdir .. '/..', FOLDER_ICON .. split(rootdir, '/')[-1] .. '/')
			endif
			return v:true

		else
			return popup_filter_menu(winid, key)

		endif
	endif
enddef

def s:diff_filter(rootdir: string, winid: number, key: string): bool
	t:dig_params['lnum'] = line('.', winid)
	var m = s:common_filter(rootdir, winid, key)
	if !empty(m)
		return m[0]
	else
		if char2nr('h') == char2nr(key)
			popup_close(winid)
			OpenDigWindow(rootdir)
			return v:true

		else
			return popup_filter_menu(winid, key)
		endif
	endif
enddef

def s:file_callback(rootdir: string, winid: number, lnum: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < lnum
		if !empty(lines[lnum - 1])
			var line: string = substitute(lines[lnum - 1], '^' .. FOLDER_ICON, '', '')
			var path: string = (empty(rootdir) ? '' : rootdir .. '/') .. line
			if isdirectory(path)
				OpenDigWindow(path)
			elseif filereadable(path)
				if &modified
					utils.ErrorMsg('The current buffer is modified.')
				else
					utils.OpenFile(path, -1)
				endif
			endif
		endif
	endif
enddef

def s:diff_callback(rootdir: string, winid: number, lnum: number)
	if 0 < lnum
		gitdiff.ShowDiff(rootdir, lnum)
	endif
enddef

