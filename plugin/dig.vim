
let g:loaded_dig = 1

command! -complete=dir -nargs=* Dig :call dig#open(<q-args>)

if get(g:, 'dig_default_mappings_enabled', v:true)
	nnoremap <silent><nowait><space>     :<C-u>Dig<cr>
endif

augroup dig
	autocmd!
	autocmd FileType dig  :nnoremap <buffer><silent><cr>      :<C-u>call dig#action('select_file', getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><space>   :<C-u>call dig#action('select_file', getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>d         :<C-u>call dig#action('git_diff')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>r         :<C-u>call dig#action('change_gitrootdir')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>t         :<C-u>call dig#action('terminal')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>e         :<C-u>call dig#action('explorer')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>s         :<C-u>call dig#action('search')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>h         :<C-u>call dig#action('updir')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>1         :<C-u>call dig#action('open_bookmark', 1)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>2         :<C-u>call dig#action('open_bookmark', 2)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>3         :<C-u>call dig#action('open_bookmark', 3)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>4         :<C-u>call dig#action('open_bookmark', 4)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>5         :<C-u>call dig#action('open_bookmark', 5)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>6         :<C-u>call dig#action('open_bookmark', 6)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>7         :<C-u>call dig#action('open_bookmark', 7)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>8         :<C-u>call dig#action('open_bookmark', 8)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>9         :<C-u>call dig#action('open_bookmark', 9)<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>l         :<C-u>call dig#action('select_file', getline('.'))<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>c         :<C-u>call dig#action('change_dir')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>~         :<C-u>call dig#open('~')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent>?         :<C-u>call dig#action('help')<cr>
	autocmd FileType dig  :nnoremap <buffer><silent><C-o>     <nop>
	autocmd FileType dig  :nnoremap <buffer><silent><C-i>     <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>i         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>a         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>I         <nop>
	autocmd FileType dig  :nnoremap <buffer><silent>A         <nop>
augroup END

