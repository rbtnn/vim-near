if !exists(':vim9script')
	finish
endif
vim9script
scriptencoding utf-8

import * as git from './git.vim'
import * as utils from './utils.vim'

const TYPE_FILE = 'file'
const TYPE_DIFF = 'diff'
const TYPE_GREP = 'grep'
const FOLDER_ICON = '📁'

export def OpenDigWindow(q_args: string, reuse_winid: number = -1, cursor_text: string = '')
	var rootdir: string = utils.FixPath(fnamemodify(expand(q_args), ':p'))
	var reload: bool = empty(get(t:, 'dig_params', {})) || !empty(q_args)
	var lines: list<string>
	var winid: number

	if !isdirectory(rootdir)
		return
	endif

	if -1 != reuse_winid
		winid = reuse_winid
	else
		winid = popup_menu([], {
				'border': [1, 1, 1, 1],
				'scrollbarhighlight': 'digScrollbar',
				'thumbhighlight': 'digThumb',
				'minwidth': &columns / 3,
				'minheight': &lines / 3,
				'maxheight': &lines / 3,
			})
		win_execute(winid, 'setfiletype dig')
		win_execute(winid, 'setlocal wincolor=Normal')
	endif

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
		if 'file' == t:dig_params['type']
			if has('win32') && ((t:dig_params['rootdir'] =~# '^[A-Z]:/\+\.\./\?$') || empty(t:dig_params['rootdir']))
				t:dig_params['rootdir'] = ''
				t:dig_params['lines'] = utils.GetDriveLetters()
			else
				t:dig_params['lines'] = utils.ReadDir(t:dig_params['rootdir'], FOLDER_ICON)
			endif
		endif
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
		win_execute(winid, 'redraw')
	endif
	t:dig_params = {
			'type': type,
			'rootdir': rootdir,
			'lines': lines,
			'lnum': lnum,
			'filter_text': filter_text,
		}
	var filtered_count = !empty(filter_text) ? printf('%d/%d', len(filtered_lines), len(lines)) : len(lines)
	var title = printf('%s(%s): %s ', type, filtered_count, empty(rootdir) ? '' : utils.FixPath(fnamemodify(rootdir, ':~')))
	if type == TYPE_FILE
		popup_setoptions(winid, {
				'title': title,
				'filter': function('s:file_filter', [rootdir]),
				'callback': function('s:file_callback', [rootdir]),
			})
	elseif type == TYPE_GREP
		popup_setoptions(winid, {
				'title': title,
				'filter': function('s:grep_filter', [rootdir]),
				'callback': function('s:grep_callback', [rootdir]),
			})
	else
		popup_setoptions(winid, {
				'title': title,
				'filter': function('s:diff_filter', [rootdir]),
				'callback': function('s:diff_callback', [rootdir]),
			})
	endif
enddef

def s:set_lnum(winid: number, lnum: number)
	win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', lnum))
enddef

def s:common_filter(rootdir: string, winid: number, key: string): list<bool>
	if char2nr('/') == char2nr(key)
		t:dig_params['filter_text'] = input('/', get(t:dig_params, 'filter_text', ''))
		s:setopts(t:dig_params['type'], winid, t:dig_params['rootdir'], t:dig_params['lines'], t:dig_params['lnum'], t:dig_params['filter_text'])
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
			var toplevel: string = git.GetRootDir(rootdir)
			if !executable('git')
				utils.ErrorMsg('git is not executable.')
			elseif empty(toplevel)
				utils.ErrorMsg('Current directory is not a git repository.')
			else
				try
					var lines: list<string> = git.Exec(fnamemodify(rootdir, ':p'))
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

		elseif char2nr('g') == char2nr(key)
			var toplevel: string = git.GetRootDir(rootdir)
			if !executable('git')
				utils.ErrorMsg('git is not executable.')
			elseif empty(toplevel)
				utils.ErrorMsg('Current directory is not a git repository.')
			else
				try
					var lines: list<string> = git.ExecGrep(fnamemodify(rootdir, ':p'))
					if empty(lines)
						utils.ErrorMsg('There are no matched lines.')
					else
						s:setopts(TYPE_GREP, winid, rootdir, lines, 1, '')
					endif
				catch /^Vim:Interrupt$/
					# nop
				endtry
			endif
			return v:true

		elseif char2nr('t') == char2nr(key)
			if !empty(rootdir)
				popup_close(winid)
				term_start(&shell, { 'cwd': rootdir, 'term_finish': 'close' })
			endif
			return v:true

		elseif char2nr('.') == char2nr(key)
			OpenDigWindow('.', winid)
			return v:true

		elseif char2nr('!') == char2nr(key)
			OpenDigWindow(rootdir, winid)
			return v:true

		elseif char2nr('~') == char2nr(key)
			OpenDigWindow('~', winid)
			return v:true

		elseif char2nr('r') == char2nr(key)
			var toplevel: string = git.GetRootDir(rootdir)
			if empty(toplevel)
				utils.ErrorMsg('Current directory is not a git repository.')
			else
				OpenDigWindow(toplevel, winid)
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
				OpenDigWindow(rootdir .. '/..', winid, FOLDER_ICON .. split(rootdir, '/')[-1] .. '/')
			endif
			return v:true

		else
			return popup_filter_menu(winid, key)

		endif
	endif
enddef

def s:grep_filter(rootdir: string, winid: number, key: string): bool
	t:dig_params['lnum'] = line('.', winid)
	var m = s:common_filter(rootdir, winid, key)
	if !empty(m)
		return m[0]
	else
		if char2nr('h') == char2nr(key)
			OpenDigWindow(rootdir, winid)
			return v:true

		else
			return popup_filter_menu(winid, key)
		endif
	endif
enddef

def s:grep_callback(rootdir: string, winid: number, lnum: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < lnum
		if !empty(lines[lnum - 1])
			var m = matchlist(lines[lnum - 1], '^\(.\{-}\):\(\d\+\):\(.*\)$')
			if !empty(m)
				var toplevel: string = git.GetRootDir(rootdir)
				var path: string = toplevel .. '/' .. m[1]
				var n: number = str2nr(m[2])
				if isdirectory(path)
					OpenDigWindow(path)
				elseif filereadable(path)
					try
						utils.OpenFile(path, n)
					catch
						utils.ErrorMsg(v:exception)
					endtry
				endif
			endif
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
			OpenDigWindow(rootdir, winid)
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
				try
					utils.OpenFile(path, -1)
				catch
					utils.ErrorMsg(v:exception)
				endtry
			endif
		endif
	endif
enddef

def s:diff_callback(rootdir: string, winid: number, lnum: number)
	if 0 < lnum
		git.ShowDiff(rootdir, lnum)
	endif
enddef

