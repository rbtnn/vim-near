
if exists("b:current_syntax")
  finish
endif

syntax match   digDirectory  '.*/$'
syntax match   digAdded      '+\d\+\s'
syntax match   digRemoved    '-\d\+\s'

highlight digTitle         gui=NONE guibg=#88ee88 guifg=#000000
highlight digDirectory     gui=NONE guibg=NONE    guifg=#77dd77

if hlexists('diffAdded')
	highlight default link digAdded   diffAdded
elseif hlexists('DiffAdd')
	highlight default link digAdded   DiffAdd
endif

if hlexists('diffRemoved')
	highlight default link digRemoved   diffRemoved
elseif hlexists('DiffDelete')
	highlight default link digRemoved   DiffDelete
endif
