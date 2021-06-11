
let s:NUMSTAT_HEAD = 12
let s:info_caches = get(s:, 'info_caches', {})
let s:keys_caches = get(s:, 'keys_caches', {})
let s:args_caches = get(s:, 'args_caches', {})
let s:git_diff_args_prev = get(s:, 'git_diff_args_prev', {})

function! dig#git#diff(path) abort
	let toplevel = dig#git#rootdir(a:path)
	let args = []
	echohl Title
	let s:git_diff_args_prev[toplevel] = input('git-diff arguments>', get(s:git_diff_args_prev, toplevel, ''))
	let args = split(s:git_diff_args_prev[toplevel], '\s\+')
	echohl None
	redraw
	let dict = {}
	let cmd = ['git', '--no-pager', 'diff', '--numstat'] + args
	if isdirectory(toplevel)
		for line in s:system(cmd, toplevel, v:true)
			let m = matchlist(line, '^\s*\(\d\+\)\s\+\(\d\+\)\s\+\(.*\)$')
			if !empty(m)
				let key = m[3]
				if !has_key(dict, key)
					let dict[key] = {
						\ 'additions' : m[1],
						\ 'deletions' : m[2],
						\ 'name' : fnamemodify(key, ':t'),
						\ 'fullpath' : s:expand2fullpath(toplevel .. '/' .. key),
						\ }
				endif
			endif
		endfor
		let ks = sort(keys(dict))
		let lines = map(deepcopy(ks), { i,key ->
			\ printf('%5s %5s %s',
			\ '+' .. dict[key]['additions'],
			\ '-' .. dict[key]['deletions'],
			\ dict[key]['name'])
			\ })
		let s:args_caches[toplevel] = args
		let s:info_caches[toplevel] = dict
		let s:keys_caches[toplevel] = ks
		return lines
	else
		return []
	endif
endfunction

function! dig#git#show_diff(rootdir, lnum) abort
	let toplevel = dig#git#rootdir(a:rootdir)
	let key = s:keys_caches[toplevel][(a:lnum - 1)]
	let fullpath = s:info_caches[toplevel][key]['fullpath']
	let args = s:args_caches[toplevel]
	let cmd = s:build_cmd(args, fullpath)
	call s:new_diff_window(s:system(cmd, toplevel, v:false), cmd)
	execute printf('nnoremap <buffer><silent><nowait><cr>       :<C-w>call <SID>jump_diff(%s)<cr>', string(fullpath))
	execute printf('nnoremap <buffer><silent><nowait>R          :<C-w>call <SID>rediff(%s, %s, %s)<cr>', string(toplevel), string(args), string(fullpath))
endfunction

function! dig#git#rootdir(path) abort
	let xs = split(a:path, '[\/]')
	let prefix = (has('mac') || has('linux')) ? '/' : ''
	while !empty(xs)
		if isdirectory(prefix .. join(xs + ['.git'], '/'))
			return s:expand2fullpath(prefix .. join(xs, '/'))
		endif
		call remove(xs, -1)
	endwhile
	return ''
endfunction

function! s:expand2fullpath(path) abort
	return dig#io#fix_path(resolve(fnamemodify(a:path, ':p')))
endfunction

function! s:system(cmd, toplevel, is_git_output) abort
	let lines = []
	if exists('*job_start')
		let path = tempname()
		try
			let job = job_start(a:cmd, {
				\ 'cwd' : a:toplevel,
				\ 'out_io' : 'file',
				\ 'out_name' : path,
				\ })
			while 'run' == job_status(job)
			endwhile
			if filereadable(path)
				let lines = readfile(path)
			endif
		finally
			if filereadable(path)
				call delete(path)
			endif
		endtry
	else
		let saved = getcwd()
		try
			lcd `=a:toplevel`
			let lines = split(system(join(a:cmd)), "\n")
		finally
			lcd `=saved`
		endtry
	endif

	let enc_from = ''
	for i in range(0, len(lines) - 1)
		if a:is_git_output
			let lines[i] = s:iconv(lines[i], 'utf-8')
		else
			" The encoding of top 4 lines('diff -...', 'index ...', '--- a/...', '+++ b/...') is always utf-8.
			if i < 4
				let lines[i] = s:iconv(lines[i], 'utf-8')
			else
				" check if the line contains a multibyte-character.
				if 0 < len(filter(split(lines[i], '\zs'), {i,x -> 0x80 < char2nr(x) }))
					if empty(enc_from)
						if dig#sillyiconv#utf_8(lines[i])
							let enc_from = 'utf-8'
						else
							let enc_from = 'shift_jis'
						endif
					endif
					let lines[i] = s:iconv(lines[i], enc_from)
				endif
			endif
		endif
	endfor

	return lines
endfunction

function! s:iconv(text, from) abort
	if a:from != &encoding
		return iconv(a:text, a:from, &encoding)
	else
		return a:text
	endif
endfunction

function! s:build_cmd(args, fullpath) abort
	return ['git', '--no-pager', 'diff'] + a:args + ['--', a:fullpath]
endfunction

function! s:rediff(toplevel, args, fullpath) abort
	let view = winsaveview()
	let cmd = s:build_cmd(a:args, a:fullpath)
	call s:new_diff_window(s:system(cmd, a:toplevel, v:false), cmd)
	call winrestview(view)
endfunction

function! s:new_diff_window(lines, cmd) abort
	if !dig#window#find_filetype('diff')
		call dig#window#new()
	endif

	setlocal noreadonly modifiable
	silent! call deletebufline('%', 1, '$')
	call setbufline('%', 1, a:lines)
	setlocal readonly nomodifiable buftype=nofile nocursorline
	let &l:filetype = 'diff'
	let &l:statusline = join(a:cmd)
endfunction

function! s:jump_diff(fullpath) abort
	let ok = v:false
	let lnum = search('^@@', 'bnW')
	if 0 < lnum
		let n1 = 0
		let n2 = 0
		for n in range(lnum + 1, line('.'))
			let line = getline(n)
			if line =~# '^-'
				let n2 += 1
			elseif line =~# '^+'
				let n1 += 1
			endif
		endfor
		let n3 = line('.') - lnum - n1 - n2 - 1
		let m = []
		let m2 = matchlist(getline(lnum), '^@@ \([+-]\)\(\d\+\)\%(,\d\+\)\? \([+-]\)\(\d\+\)\%(,\d\+\)\?\s*@@\(.*\)$')
		let m3 = matchlist(getline(lnum), '^@@@ \([+-]\)\(\d\+\)\%(,\d\+\)\? \([+-]\)\(\d\+\)\%(,\d\+\)\? \([+-]\)\(\d\+\),\d\+\s*@@@\(.*\)$')
		if !empty(m2)
			let m = m2
		elseif !empty(m3)
			let m = m3
		endif
		if !empty(m)
			for i in [1, 3, 5]
				if '+' == m[i]
					if filereadable(a:fullpath)
						let lnum = m[i + 1] + n1 + n3
						if dig#window#find_path(a:fullpath)
							execute printf('%d', lnum)
						else
							call dig#window#new()
							call dig#window#open(a:fullpath, lnum)
						endif
						silent! foldopen!
						normal! zz
					endif
					let ok = v:true
					break
				endif
			endfor
		endif
	endif
	if !ok
		call dig#io#error('Can not jump this!')
	endif
endfunction

