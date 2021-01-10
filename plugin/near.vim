
let g:loaded_near = 1

command! -complete=dir -nargs=* Near :call near#open(<q-args>)

augroup near
	autocmd!
	autocmd WinLeave *     :call near#close()
	autocmd FileType near  :nnoremap <buffer><silent><cr>      :<C-u>call near#select_file(getline('.'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent><space>   :<C-u>call near#select_file(getline('.'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent>h         :<C-u>call near#open(fnamemodify(get(t:near, 'rootdir', '.'), ':p:h:h'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent>l         :<C-u>call near#select_file(getline('.'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent>c         :<C-u>call near#change_dir()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>~         :<C-u>call near#open('~')<cr>
	autocmd FileType near  :nnoremap <buffer><silent>?         :<C-u>call near#help()<cr>
augroup END

