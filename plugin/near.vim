
let g:loaded_near = 1

command! -complete=dir -nargs=* Near :call near#exec(<q-args>)

augroup near
	autocmd!
	autocmd WinLeave *     :call near#try_close()
	autocmd WinEnter *     :call near#restore_view()
augroup END

