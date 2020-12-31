
let s:TEST_LOG = expand('<sfile>:h:h:gs?\?/?') . '/test.log'

let g:near_ignoredirs = get(g:, 'near_ignoredirs', ['node_modules', '.git', '.svn', '_svn', '.dotnet'])
let g:near_maxdepth = get(g:, 'near_maxdepth', 2)

function! near#exec(q_args) abort
	if &filetype == 'near'
		call near#try_close()
	endif
	let rootdir = s:fix_path(isdirectory(expand(a:q_args)) ? expand(a:q_args) : getcwd())
	let t:near = {
		\ 'prev_view' : winsaveview(),
		\ 'prev_winid' : win_getid(),
		\ 'rootdir' : rootdir,
		\ }
	rightbelow vnew
	let t:near['near_winid'] = win_getid()
	setlocal noreadonly modified
	let lines = s:readdir_rec(rootdir, rootdir, g:near_maxdepth)
	silent! call deletebufline('%', 1, '$')
	call setbufline('%', 1, lines)
	let width = max(map(copy(lines), { _,x -> strdisplaywidth(x) })) + 1
	execute printf('vertical resize %d', width)
	setlocal buftype=nofile readonly nomodified nobuflisted filetype=near
	let &l:statusline = printf('[near] %s', rootdir)
	nnoremap <buffer><silent><cr>   :<C-u>call <SID>open(getline('.'))<cr>
endfunction

function! near#try_close() abort
	let t:near = get(t:, 'near', {})
	if get(t:near, 'near_winid', -1) == win_getid()
		close
		execute printf('%dwincmd w', win_id2win(t:near['prev_winid']))
	endif
	" Because WinEnter event is not emited when Ctrl-w_c in a near window.
	call near#restore_view()
endfunction

function! near#restore_view() abort
	let t:near = get(t:, 'near', {})
	if (get(t:near, 'prev_winid', -1) == win_getid()) && !empty(get(t:near, 'prev_view', {}))
		call winrestview(get(t:near, 'prev_view', {}))
	endif
endfunction

function! near#run_tests() abort
	if filereadable(s:TEST_LOG)
		call delete(s:TEST_LOG)
	endif
	let v:errors = []
	call assert_equal(
		\ s:readdir_rec('.', '.', 0),
		\ [])
	call assert_equal(
		\ s:readdir_rec('.', '.', 1),
		\ ['.github/', 'LICENSE', 'README.md', 'autoload/', 'plugin/', 'syntax/'])
	call assert_equal(
		\ s:readdir_rec('.', '.', 2),
		\ ['.github/workflows/', 'LICENSE', 'README.md', 'autoload/near.vim', 'plugin/near.vim', 'syntax/near.vim'])
	call assert_equal(
		\ s:readdir_rec('.', '.', 3),
		\ ['.github/workflows/vim.yml', 'LICENSE', 'README.md', 'autoload/near.vim', 'plugin/near.vim', 'syntax/near.vim'])
	call assert_equal(
		\ s:readdir_rec('./plugin', './plugin', 0),
		\ [])
	call assert_equal(
		\ s:readdir_rec('./plugin', './plugin', 1),
		\ ['near.vim'])
	call assert_equal(
		\ s:readdir_rec('./plugin', './plugin', 2),
		\ ['near.vim'])
	call assert_equal(
		\ s:readdir_rec('./syntax', './syntax', 0),
		\ [])
	call assert_equal(
		\ s:readdir_rec('./syntax', './syntax', 1),
		\ ['near.vim'])
	call assert_equal(
		\ s:readdir_rec('./syntax', './syntax', 2),
		\ ['near.vim'])
	call assert_equal(
		\ s:readdir_rec('./.github', './.github', 0),
		\ [])
	call assert_equal(
		\ s:readdir_rec('./.github', './.github', 1),
		\ ['workflows/'])
	call assert_equal(
		\ s:readdir_rec('./.github', './.github', 2),
		\ ['workflows/vim.yml'])
	if !empty(v:errors)
		call writefile(v:errors, s:TEST_LOG)
		for err in v:errors
			echohl Error
			echo err
			echohl None
		endfor
	endif
endfunction



function! s:fix_path(path) abort
	return substitute(a:path, '[\/]\+', '/', 'g')
endfunction

function! s:open(line) abort
	let t:near = get(t:, 'near', {})
	if (get(t:near, 'near_winid', -1) == win_getid())
		let path = s:fix_path(t:near['rootdir'] .. '/' .. a:line)
		if filereadable(path)
			call near#try_close()
			if -1 == bufnr(path)
				execute printf('edit %s', escape(path, '\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call near#exec(path)
		endif
	endif
endfunction

function! s:readdir_rec(rootdir, path, depth) abort
	let xs = []
	if 0 < a:depth
		let rootdir = a:rootdir
		if !empty(rootdir) && ('/' != split(rootdir, '\zs')[-1])
			let rootdir = rootdir .. '/'
		endif
		try
			for name in readdir(a:path)
				let relpath = s:fix_path(a:path .. '/' .. name)
				if empty(expand(relpath))
					continue
				endif
				if filereadable(relpath)
					if rootdir == relpath[:len(rootdir) - 1]
						let xs += [relpath[len(rootdir):]]
					else
						let xs += [relpath]
					endif
				elseif isdirectory(relpath) && (-1 == index(g:near_ignoredirs, name))
					if 0 < a:depth - 1
						let xs += s:readdir_rec(rootdir, relpath, a:depth - 1)
					else
						if rootdir == relpath[:len(rootdir) - 1]
							let xs += [relpath[len(rootdir):] .. '/']
						else
							let xs += [relpath .. '/']
						endif
					endif
				endif
			endfor
		catch
			echohl Error
			echo v:exception
			echohl None
		endtry
	endif
	return sort(xs)
endfunction

