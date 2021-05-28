
if exists("b:current_syntax")
  finish
endif

syntax match   digDir      '.*/$'
highlight default link digDir   Directory
