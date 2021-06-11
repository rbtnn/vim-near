
let g:loaded_dig = 1

if has('nvim')
	finish
endif

command! -complete=dir -nargs=* Dig :call dig#open(<q-args>)

nnoremap <silent><nowait><space>     :<C-u>Dig<cr>

