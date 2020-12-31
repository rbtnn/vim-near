
if exists("b:current_syntax")
  finish
endif

syntax match   nearDir      '.*/$'
highlight default link nearDir   Directory
