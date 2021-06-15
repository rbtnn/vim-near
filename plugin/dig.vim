vim9script
import * as dig from '../import/dig.vim'

command! -complete=dir -nargs=* Dig  :call dig#open(<q-args>)
command! -complete=dir -nargs=* Dig9 :vim9cmd dig.Open(<q-args>)

nnoremap <silent><nowait><space>     :<C-u>Dig9<cr>
