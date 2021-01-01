
let s:TEST_LOG = expand('<sfile>:h:h:gs?\?/?') . '/test.log'

let g:near_ignoredirs = get(g:, 'near_ignoredirs', ['node_modules', '.git', '.svn', '_svn'])
let g:near_maxdepth = get(g:, 'near_maxdepth', 2)

function! near#open(q_args) abort
	if &filetype == 'near'
		call near#close()
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
endfunction

function! near#close() abort
	call s:construct_or_init()
	if t:near['near_winid'] == win_getid()
		close
		if (0 < win_id2win(t:near['prev_winid'])) && !empty(t:near['prev_view'])
			execute printf('%dwincmd w', win_id2win(t:near['prev_winid']))
			call winrestview(t:near['prev_view'])
		endif
		call s:construct_or_init(v:true)
	endif
endfunction

function! near#run_tests() abort
	let saved_wildignore = &wildignore
	try
		if filereadable(s:TEST_LOG)
			call delete(s:TEST_LOG)
		endif
		let v:errors = []
		set wildignore=*.gif
		if has('nvim')
			set wildignore+=.nvimlog
		endif

		call assert_equal(
			\ sort(s:readdir_rec('.', '.', 0)),
			\ sort([]))
		call assert_equal(
			\ sort(s:readdir_rec('.', '.', 1)),
			\ sort(['.github/', 'LICENSE', 'README.md', 'autoload/', 'plugin/', 'syntax/']))
		call assert_equal(
			\ sort(s:readdir_rec('.', '.', 2)),
			\ sort(['.github/workflows/', 'LICENSE', 'README.md', 'autoload/near.vim', 'plugin/near.vim', 'syntax/near.vim']))
		call assert_equal(
			\ sort(s:readdir_rec('.', '.', 3)),
			\ sort(['.github/workflows/neovim.yml', '.github/workflows/vim.yml', 'LICENSE', 'README.md', 'autoload/near.vim', 'plugin/near.vim', 'syntax/near.vim']))
		call assert_equal(
			\ sort(s:readdir_rec('./plugin', './plugin', 0)),
			\ sort([]))
		call assert_equal(
			\ sort(s:readdir_rec('./plugin', './plugin', 1)),
			\ sort(['near.vim']))
		call assert_equal(
			\ sort(s:readdir_rec('./plugin', './plugin', 2)),
			\ sort(['near.vim']))
		call assert_equal(
			\ sort(s:readdir_rec('./syntax', './syntax', 0)),
			\ sort([]))
		call assert_equal(
			\ sort(s:readdir_rec('./syntax', './syntax', 1)),
			\ sort(['near.vim']))
		call assert_equal(
			\ sort(s:readdir_rec('./syntax', './syntax', 2)),
			\ sort(['near.vim']))
		call assert_equal(
			\ sort(s:readdir_rec('./.github', './.github', 0)),
			\ sort([]))
		call assert_equal(
			\ sort(s:readdir_rec('./.github', './.github', 1)),
			\ sort(['workflows/']))
		call assert_equal(
			\ sort(s:readdir_rec('./.github', './.github', 2)),
			\ sort(['workflows/neovim.yml', 'workflows/vim.yml']))

		if !empty(v:errors)
			call writefile(v:errors, s:TEST_LOG)
			for err in v:errors
				echohl Error
				echo err
				echohl None
			endfor
		endif
	finally
		let &wildignore = saved_wildignore
	endtry
endfunction

function! near#select_file(line) abort
	call s:construct_or_init()
	if (t:near['near_winid'] == win_getid())
		let path = s:fix_path(t:near['rootdir'] .. '/' .. a:line)
		if filereadable(path)
			call near#close()
			if -1 == bufnr(path)
				execute printf('edit %s', escape(path, '\ '))
			else
				execute printf('buffer %d', bufnr(path))
			endif
		elseif isdirectory(path)
			call near#open(path)
		endif
	endif
endfunction



function! s:construct_or_init(force_init = v:false) abort
	if a:force_init
		let t:near = {}
	else
		let t:near = get(t:, 'near', {})
	endif
	let t:near['near_winid'] = get(t:near, 'near_winid', -1)
	let t:near['prev_view'] = get(t:near, 'prev_view', {})
	let t:near['prev_winid'] = get(t:near, 'prev_winid', -1)
	let t:near['rootdir'] = get(t:near, 'rootdir', '')
endfunction

function! s:fix_path(path) abort
	return substitute(a:path, '[\/]\+', '/', 'g')
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
	return xs
endfunction

