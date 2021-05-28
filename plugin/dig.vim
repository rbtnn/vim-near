
let g:loaded_dig = 1

command! -complete=dir -nargs=* Dig :call dig#open(<q-args>)

augroup dig
	autocmd!
	autocmd WinLeave *    :call dig#close()
	autocmd FileType dig  :nnoremap <buffer><silent><cr>      :<C-u>call dig#select_file(getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><space>   :<C-u>call dig#select_file(getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><esc>     :<C-u>call dig#close()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>d         :<C-u>call dig#git_diff()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>r         :<C-u>call dig#change_gitrootdir()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>t         :<C-u>call dig#terminal()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>e         :<C-u>call dig#explorer()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>s         :<C-u>call dig#search()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>h         :<C-u>call dig#updir()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>l         :<C-u>call dig#select_file(getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>c         :<C-u>call dig#change_dir()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>~         :<C-u>call dig#open('~')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>?         :<C-u>call dig#help()<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><C-o>     <nop>
	autocmd FileType dig  :nnoremap <buffer><silent><C-i>     <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>i         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>a         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>I         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>A         <nop>
augroup END

