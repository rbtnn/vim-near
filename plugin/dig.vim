
let g:loaded_dig = 1

command! -complete=dir -nargs=* Dig :call dig#open(<q-args>)

nnoremap <silent><nowait><space>     :<C-u>Dig<cr>

augroup dig
	autocmd!
	autocmd FileType dig  :nnoremap <buffer><silent><cr>      :<C-u>call dig#action('select_file', getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><space>   :<C-u>call dig#action('select_file', getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>d         :<C-u>call dig#action('git_diff')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>r         :<C-u>call dig#action('goto_gitrootdir')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>t         :<C-u>call dig#action('terminal')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>e         :<C-u>call dig#action('explorer')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>s         :<C-u>call dig#action('search')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>h         :<C-u>call dig#action('updir')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>l         :<C-u>call dig#action('select_file', getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>~         :<C-u>call dig#action('home')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>?         :<C-u>call dig#action('help')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><C-o>     <nop>
	autocmd FileType dig  :nnoremap <buffer><silent><C-i>     <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>i         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>a         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>I         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>A         <nop>
augroup END

