if !exists(':vim9script')
	finish
endif
vim9script

import * as dig from '../import/dig.vim'

command! -complete=dir -nargs=* Dig :vim9cmd dig.OpenDigWindow(<q-args>)

