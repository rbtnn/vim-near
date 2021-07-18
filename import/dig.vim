if !exists(':vim9script')
	finish
endif
vim9script
scriptencoding utf-8

import * as git from './git.vim'
import * as utils from './utils.vim'

const FOLDER_ICON = '📁'
const TYPE_FILE = 'file'
const TYPE_DIFF = 'diff'
const INPUT_MODE_MENU = 'menu'
const INPUT_MODE_SEARCH = 'search'
const INPUT_MODE_GITDIFF = 'gitdiff'

export def OpenDigWindow(q_args: string, reuse_winid: number = -1, cursor_text: string = '')
	var rootdir: string = utils.FixPath(fnamemodify(expand(q_args), ':p'))
	var winid: number

	if !isdirectory(rootdir)
		return
	endif

	if -1 != reuse_winid
		winid = reuse_winid
	else
		winid = popup_menu([], {
				'border': [1, 1, 1, 1],
				'padding': [1, 1, 1, 1],
				'scrollbarhighlight': 'digScrollbar',
				'thumbhighlight': 'digThumb',
				'minwidth': &columns / 2,
				'maxwidth': &columns / 2,
				'minheight': &lines / 3,
				'maxheight': &lines / 3,
			})
		win_execute(winid, 'setfiletype dig')
		win_execute(winid, 'setlocal wincolor=Normal')
	endif

	if !empty(q_args) || empty(get(t:, 'dig_params', {}))
		t:dig_params = {
			'rootdir': rootdir,
			'type': TYPE_FILE,
			'lnum': 1,
			'lines': [],
			'input_mode': INPUT_MODE_MENU,
			'input_winid': -1,
			'search_text': '',
			'gitdiff_text': '',
		}
	endif

	if TYPE_FILE == t:dig_params['type']
		if has('win32') && ((t:dig_params['rootdir'] =~# '^[A-Z]:/\+\.\./\?$') || empty(t:dig_params['rootdir']))
			t:dig_params['rootdir'] = ''
			t:dig_params['lines'] = utils.GetDriveLetters()
		else
			t:dig_params['lines'] = utils.ReadDir(t:dig_params['rootdir'], FOLDER_ICON)
		endif
	endif

	s:redraw(winid)

	if !empty(cursor_text)
		var i = index(t:dig_params['lines'], cursor_text)
		if -1 != i
			s:set_lnum(winid, i + 1)
		endif
	endif
enddef



def s:make_title(filtered_lines: list<string>): string
	var lines = t:dig_params['lines']
	var rootdir = t:dig_params['rootdir']
	var search_text = t:dig_params['search_text']
	var t = (INPUT_MODE_MENU != t:dig_params['input_mode']) ? t:dig_params['input_mode'] : t:dig_params['type']
	var c = empty(search_text) ? len(lines) : printf('%d/%d', len(filtered_lines), len(lines))
	var s = empty(rootdir) ? '' : utils.FixPath(fnamemodify(rootdir, ':~'))
	return printf('%s(%s): %s ', t, c, s)
enddef

def s:set_filtered_lines(winid: number)
	var filtered_lines: list<string>
	clearmatches(winid)
	if !empty(t:dig_params['search_text'])
		var pattern = ''
		for c in split(t:dig_params['search_text'], '\zs')
			if (char2nr('A') <= char2nr(c)) && (char2nr(c) <= char2nr('Z'))
				pattern = pattern .. printf('\%(\%%x%02x\|\%%x%02x\)', char2nr(c), char2nr(c) + 0x20)
			elseif (char2nr('a') <= char2nr(c)) && (char2nr(c) <= char2nr('z'))
				pattern = pattern .. printf('\%(\%%x%02x\|\%%x%02x\)', char2nr(c), char2nr(c) - 0x20)
			else
				pattern = pattern .. printf('\%%x%02x', char2nr(c))
			endif
		endfor
		for line in t:dig_params['lines']
			# ignorecase
			if line =~? pattern
				filtered_lines += [line]
			endif
		endfor
		popup_settext(winid, filtered_lines)
		s:set_lnum(winid, 1)
		win_execute(winid, printf("matchadd('Search', %s)", string(pattern)))
	else
		popup_settext(winid, t:dig_params['lines'])
		s:set_lnum(winid, t:dig_params['lnum'])
		win_execute(winid, 'redraw')
	endif
	popup_setoptions(winid, { 'title': s:make_title(filtered_lines), })
enddef

def s:set_searchwin(winid: number)
	popup_close(t:dig_params['input_winid'])
	if INPUT_MODE_SEARCH == t:dig_params['input_mode']
		t:dig_params['input_winid'] = popup_create('/' .. t:dig_params['search_text'], {})
		var info = popup_getpos(winid)
		popup_setoptions(t:dig_params['input_winid'], {
			'pos': 'topleft',
			'line': info['line'] + 1,
			'col': info['col'] + 2,
			'zindex': 9999,
			'highlight': 'Directory',
			})
	elseif INPUT_MODE_GITDIFF == t:dig_params['input_mode']
		t:dig_params['input_winid'] = popup_create('>' .. t:dig_params['gitdiff_text'], {})
		var info = popup_getpos(winid)
		popup_setoptions(t:dig_params['input_winid'], {
			'pos': 'topleft',
			'line': info['line'] + 1,
			'col': info['col'] + 2,
			'zindex': 9999,
			'highlight': 'Directory',
			})
	else
		t:dig_params['input_winid'] = -1
	endif
enddef

def s:redraw(winid: number)
	s:set_filtered_lines(winid)
	if t:dig_params['type'] == TYPE_FILE
		popup_setoptions(winid, {
				'filter': function('s:file_filter', [(t:dig_params['rootdir'])]),
				'callback': function('s:file_callback', [(t:dig_params['rootdir'])]),
			})
	else
		popup_setoptions(winid, {
				'filter': function('s:diff_filter', [(t:dig_params['rootdir'])]),
				'callback': function('s:diff_callback', [(t:dig_params['rootdir'])]),
			})
	endif
	s:set_searchwin(winid)
enddef

def s:set_lnum(winid: number, lnum: number)
	win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', lnum))
enddef

def s:input_common_filter(winid: number, key: string, key_mode: string, key_text: string): list<bool>
	if 0x1b == char2nr(key) # Esc
		return [popup_filter_menu(winid, "\<Esc>")]
	elseif 0x08 == char2nr(key) # Ctrl-h
		if empty(t:dig_params[key_text])
			t:dig_params[key_mode] = INPUT_MODE_MENU
			t:dig_params[key_text] = ''
		else
			t:dig_params[key_text] = join(split(t:dig_params[key_text], '\zs')[: -2], '')
		endif
	elseif 0x15 == char2nr(key) # Ctrl-u
		t:dig_params[key_text] = ''
	elseif (strtrans(key) != '^@') && (1 == len(strtrans(key)))
		t:dig_params[key_text] = t:dig_params[key_text] .. key
	endif
	s:redraw(winid)
	return [(v:true)]
enddef

def s:common_filter(rootdir: string, winid: number, key: string): list<bool>
	if INPUT_MODE_SEARCH == t:dig_params['input_mode']
		if char2nr("\r") == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_MENU
			s:redraw(winid)
			return [(v:true)]
		else
			return s:input_common_filter(winid, key, 'input_mode', 'search_text')
		endif

	elseif INPUT_MODE_GITDIFF == t:dig_params['input_mode']
		if char2nr("\r") == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_MENU
			var toplevel: string = git.GetRootDir(rootdir)
			if !executable('git')
				utils.ErrorMsg('git is not executable.')
			elseif empty(toplevel)
				utils.ErrorMsg('Current directory is not a git repository.')
			else
				try
					var lines: list<string> = git.Exec(fnamemodify(rootdir, ':p'), t:dig_params['gitdiff_text'])
					if empty(lines)
						utils.ErrorMsg('There are no modified files.')
					else
						t:dig_params['type'] = TYPE_DIFF
						t:dig_params['rootdir'] = rootdir
						t:dig_params['lines'] = lines
						t:dig_params['lnum'] = 1
						t:dig_params['search_text'] = ''
					endif
				catch /^Vim:Interrupt$/
					# nop
				endtry
			endif
			s:redraw(winid)
			return [(v:true)]
		else
			return s:input_common_filter(winid, key, 'input_mode', 'gitdiff_text')
		endif

	else
		if char2nr('/') == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_SEARCH
			s:redraw(winid)
			return [(v:true)]

		elseif char2nr('g') == char2nr(key)
			s:set_lnum(winid, 1)
			return [(v:true)]

		elseif char2nr('G') == char2nr(key)
			s:set_lnum(winid, line('$', winid))
			return [(v:true)]

		elseif char2nr('l') == char2nr(key)
			return [popup_filter_menu(winid, "\<cr>")]

		else
			return []
		endif
	endif
enddef

def s:file_filter(rootdir: string, winid: number, key: string): bool
	t:dig_params['lnum'] = line('.', winid)
	var m = s:common_filter(rootdir, winid, key)
	if !empty(m)
		return m[0]
	else
		if char2nr('d') == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_GITDIFF
			s:redraw(winid)
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
	popup_close(get(t:dig_params, 'input_winid', -1))
enddef

def s:diff_callback(rootdir: string, winid: number, lnum: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < lnum
		if !empty(lines[lnum - 1])
			git.ShowDiff(rootdir, lnum)
		endif
	endif
enddef

