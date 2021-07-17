
if exists("b:current_syntax")
  finish
endif

syntax match   digDirectory  '.*/$'
syntax match   digAdded      '+\d\+\s'
syntax match   digRemoved    '-\d\+\s'
syntax match   digGrepPath   '^.\{-}:\d\+:' contains=digGrepLnum
syntax match   digGrepLnum   '\d\+' contained

highlight digDirectory     gui=NONE guibg=NONE    guifg=#b5bd68
highlight digScrollbar     gui=NONE guibg=#202020 guifg=#000000
highlight digThumb         gui=NONE guibg=#606060 guifg=#000000

highlight default link digGrepPath   Directory
highlight default link digGrepLnum   Title

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
