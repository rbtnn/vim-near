
if exists("b:current_syntax")
  finish
endif

syntax match   digDir        '.*/$'
syntax match   digAdded      '\s+\d\+\s'
syntax match   digRemoved    '\s-\d\+\s'

highlight default link digDir   Directory

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
