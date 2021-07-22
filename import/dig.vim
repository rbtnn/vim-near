if !exists(':vim9script')
	finish
endif
vim9script
scriptencoding utf-8

import * as git from './git.vim'
import * as utils from './utils.vim'

const FOLDER_ICON = '📁'
const TYPE_FILE = 'file'
const TYPE_GITDIFF = 'git-diff'
const TYPE_GITLS = 'git-ls'
const TYPE_GITGREP = 'git-grep'
const INPUT_MODE_DEFAULT = 'default'
const INPUT_MODE_FILTER = 'filter'
const INPUT_MODE_GITDIFF = 'git-diff'
const INPUT_MODE_GITGREP = 'git-grep'

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
				'border': [0, 0, 0, 0],
				'padding': [2, 1, 1, 1],
				'scrollbarhighlight': 'digScrollbar',
				'thumbhighlight': 'digThumb',
				'minwidth': &columns / 3 * 2,
				'maxwidth': &columns / 3 * 2,
				'minheight': &lines / 3,
				'maxheight': &lines / 3,
			})
		win_execute(winid, 'setfiletype dig')
		win_execute(winid, 'setlocal wrap')
	endif

	if !empty(q_args) || empty(get(t:, 'dig_params', {}))
		t:dig_params = {
			'rootdir': rootdir,
			'type': TYPE_FILE,
			'lnum': 1,
			'lines': [],
			'input_mode': INPUT_MODE_DEFAULT,
			'search_text': '',
			'gitdiff_text': '',
			'gitgrep_text': '',
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



def s:redraw(winid: number)
	var d: dict<list<string>>
	var n: number = 1
	var type = t:dig_params['type']
	var lines = t:dig_params['lines']
	var rootdir = t:dig_params['rootdir']
	var search_text = t:dig_params['search_text']
	var input_mode = t:dig_params['input_mode']

	d[TYPE_FILE] = ['s:file_filter', 's:file_callback']
	d[TYPE_GITLS] = ['s:gitls_filter', 's:gitls_callback']
	d[TYPE_GITGREP] = ['s:gitgrep_filter', 's:gitgrep_callback']
	d[TYPE_GITDIFF] = ['s:gitdiff_filter', 's:gitdiff_callback']

	popup_setoptions(winid, {
			'filter': function(d[type][0], [rootdir]),
			'callback': function(d[type][1], [rootdir]),
		})

	clearmatches(winid)
	silent! call deletebufline(winbufnr(winid), 1, line('$', winid))
	try
		for line in lines
			if (line =~? search_text) || empty(search_text)
				setbufline(winbufnr(winid), n, line)
				n += 1
			endif
		endfor
		if !empty(search_text)
			win_execute(winid, printf("matchadd('Search', %s)", string((&ignorecase ? '\c' : '') .. search_text)))
		endif
	catch
	endtry

	s:set_lnum(winid, t:dig_params['lnum'])
	win_execute(winid, 'redraw')
	if INPUT_MODE_FILTER == input_mode
		popup_setoptions(winid, { 'title': (input_mode .. '>' .. search_text), })
	elseif INPUT_MODE_GITDIFF == input_mode
		popup_setoptions(winid, { 'title': (input_mode .. '>' .. t:dig_params['gitdiff_text']), })
	elseif INPUT_MODE_GITGREP == input_mode
		popup_setoptions(winid, { 'title': (input_mode .. '>' .. t:dig_params['gitgrep_text']), })
	else
		var t = (INPUT_MODE_DEFAULT != input_mode) ? input_mode : type
		var c = empty(search_text) ? len(lines) : printf('%d/%d', n - 1, len(lines))
		var s = empty(rootdir) ? '' : utils.FixPath(fnamemodify(rootdir, ':~'))
		popup_setoptions(winid, { 'title': printf('%s(%s): %s ', t, c, s), })
	endif
enddef

def s:set_lnum(winid: number, lnum: number)
	win_execute(winid, printf('call setpos(".", [0, %d, 1, 0])', lnum))
enddef

def s:input_common_filter(winid: number, key: string, key_mode: string, key_text: string): list<bool>
	if 0x1b == char2nr(key) # Esc
		return [popup_filter_menu(winid, "\<Esc>")]
	elseif 0x08 == char2nr(key) # Ctrl-h
		if empty(t:dig_params[key_text])
			t:dig_params[key_mode] = INPUT_MODE_DEFAULT
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

def s:execute_git(rootdir: string, type: string)
	var toplevel: string = git.GetRootDir(rootdir)
	if !executable('git')
		utils.ErrorMsg('git is not executable.')
	elseif empty(toplevel)
		utils.ErrorMsg('Current directory is not a git repository.')
	else
		try
			if TYPE_GITGREP == type
				t:dig_params['lines'] = git.ExecGrep(fnamemodify(rootdir, ':p'), t:dig_params['gitgrep_text'])
			elseif TYPE_GITDIFF == type
				t:dig_params['lines'] = git.ExecDiff(fnamemodify(rootdir, ':p'), t:dig_params['gitdiff_text'])
			elseif TYPE_GITLS == type
				t:dig_params['lines'] = git.ExecLs(toplevel)
			else
				t:dig_params['lines'] = []
			endif
			t:dig_params['type'] = type
			t:dig_params['rootdir'] = rootdir
			t:dig_params['lnum'] = 1
			t:dig_params['search_text'] = ''
		catch /^Vim:Interrupt$/
			# nop
		endtry
	endif
enddef

def s:common_filter(rootdir: string, winid: number, key: string): list<bool>
	if INPUT_MODE_FILTER == t:dig_params['input_mode']
		if char2nr("\r") == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_DEFAULT
			s:redraw(winid)
			return [(v:true)]
		else
			return s:input_common_filter(winid, key, 'input_mode', 'search_text')
		endif

	elseif INPUT_MODE_GITGREP == t:dig_params['input_mode']
		if char2nr("\r") == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_DEFAULT
			s:execute_git(rootdir, TYPE_GITGREP)
			s:redraw(winid)
			return [(v:true)]
		else
			return s:input_common_filter(winid, key, 'input_mode', 'gitgrep_text')
		endif

	elseif INPUT_MODE_GITDIFF == t:dig_params['input_mode']
		if char2nr("\r") == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_DEFAULT
			s:execute_git(rootdir, TYPE_GITDIFF)
			s:redraw(winid)
			return [(v:true)]
		else
			return s:input_common_filter(winid, key, 'input_mode', 'gitdiff_text')
		endif

	else
		if char2nr('/') == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_FILTER
			t:dig_params['lnum'] = 1
			s:redraw(winid)
			return [(v:true)]

		elseif char2nr('g') == char2nr(key)
			s:set_lnum(winid, 1)
			return [(v:true)]

		elseif char2nr('G') == char2nr(key)
			s:set_lnum(winid, line('$', winid))
			return [(v:true)]

		elseif char2nr('q') == char2nr(key)
			return [popup_filter_menu(winid, "\<esc>")]

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

		elseif char2nr('s') == char2nr(key)
			t:dig_params['input_mode'] = INPUT_MODE_GITGREP
			s:redraw(winid)
			return v:true

		elseif char2nr('f') == char2nr(key)
			s:execute_git(rootdir, TYPE_GITLS)
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

		elseif char2nr('%') == char2nr(key)
			OpenDigWindow(expand('%:h'), winid)
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

def s:gitdiff_filter(rootdir: string, winid: number, key: string): bool
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

def s:gitls_filter(rootdir: string, winid: number, key: string): bool
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

def s:gitgrep_filter(rootdir: string, winid: number, key: string): bool
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

def s:file_callback(rootdir: string, winid: number, n: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < n
		if !empty(lines[n - 1])
			var line: string = substitute(lines[n - 1], '^' .. FOLDER_ICON, '', '')
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

def s:gitdiff_callback(rootdir: string, winid: number, n: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < n
		if !empty(lines[n - 1])
			git.ShowDiff(rootdir, n)
		endif
	endif
enddef

def s:gitls_callback(rootdir: string, winid: number, n: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < n
		if !empty(lines[n - 1])
			var toplevel: string = git.GetRootDir(rootdir)
			var line: string = substitute(lines[n - 1], '^' .. FOLDER_ICON, '', '')
			var path: string = (empty(toplevel) ? '' : toplevel .. '/') .. line
			if filereadable(path)
				try
					utils.OpenFile(path, -1)
				catch
					utils.ErrorMsg(v:exception)
				endtry
			endif
		endif
	endif
enddef

def s:gitgrep_callback(rootdir: string, winid: number, n: number)
	var lines: list<string> = getbufline(winbufnr(winid), 1, '$')
	if 0 < n
		if !empty(lines[n - 1])
			var m: list<string> = matchlist(lines[n - 1], '^\(.\{-\}\):\(\d\+\):')
			if !empty(m)
				var path: string = rootdir .. '/' .. m[1]
				if filereadable(path)
					try
						utils.OpenFile(path, str2nr(m[2]))
					catch
						utils.ErrorMsg(v:exception)
					endtry
				endif
			endif
		endif
	endif
enddef
