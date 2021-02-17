
let g:loaded_near = 1

command! -complete=dir -nargs=* Near :call near#open(<q-args>)

augroup near
	autocmd!
	autocmd WinLeave *     :call near#close()
	autocmd FileType near  :nnoremap <buffer><silent><cr>      :<C-u>call near#select_file(getline('.'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent><space>   :<C-u>call near#select_file(getline('.'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent><esc>     :<C-u>call near#close()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>t         :<C-u>call near#terminal()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>e         :<C-u>call near#explorer()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>s         :<C-u>call near#search()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>h         :<C-u>call near#updir()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>l         :<C-u>call near#select_file(getline('.'))<cr>
	autocmd FileType near  :nnoremap <buffer><silent>c         :<C-u>call near#change_dir()<cr>
	autocmd FileType near  :nnoremap <buffer><silent>~         :<C-u>call near#open('~')<cr>
	autocmd FileType near  :nnoremap <buffer><silent>?         :<C-u>call near#help()<cr>
	autocmd FileType near  :nnoremap <buffer><silent><C-o>     <nop>
	autocmd FileType near  :nnoremap <buffer><silent><C-i>     <nop>
augroup END

