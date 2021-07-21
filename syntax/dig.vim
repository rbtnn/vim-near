
if exists("b:current_syntax")
  finish
endif

" -----
" basic
" -----
syntax match   digDirectory    '.*/$'
highlight digDirectory     gui=NONE guibg=NONE    guifg=#b5bd68
highlight digScrollbar     gui=NONE guibg=#202020 guifg=#000000
highlight digThumb         gui=NONE guibg=#606060 guifg=#000000

" --------
" git-diff
" --------
syntax match   digDiffLine     '^\s*+\d\+\s\+-\d\+\s.*$' contains=digDiffAdded,digDiffRemoved
syntax match   digDiffAdded    '+\d\+\s'                 contained
syntax match   digDiffRemoved  '-\d\+\s'                 contained
highlight default link digGrepLine   Normal
highlight default link digDiffLine   Normal

" --------
" git-grep
" --------
syntax match   digGrepLine     '^.\{-}:\d\+:.*$' contains=digGrepPath
syntax match   digGrepPath     '^.\{-}:\d\+:'    contains=digGrepLnum contained
syntax match   digGrepLnum     '\d\+'                                 contained
highlight default link digGrepPath   Directory
highlight default link digGrepLnum   Title
if hlexists('diffAdded')
	highlight default link digDiffAdded   diffAdded
elseif hlexists('DiffAdd')
	highlight default link digDiffAdded   DiffAdd
endif
if hlexists('diffRemoved')
	highlight default link digDiffRemoved   diffRemoved
elseif hlexists('DiffDelete')
	highlight default link digDiffRemoved   DiffDelete
endif
