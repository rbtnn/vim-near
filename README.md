
# vim-near
[![vim](https://github.com/rbtnn/vim-near/workflows/vim/badge.svg)](https://github.com/rbtnn/vim-near/actions?query=workflow%3Avim)
[![neovim](https://github.com/rbtnn/vim-near/workflows/neovim/badge.svg)](https://github.com/rbtnn/vim-near/actions?query=workflow%3Aneovim)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This plugin provides to select a file in directories of maxdepth 2.
This plugin is like [preservim/nerdtree](https://github.com/preservim/nerdtree).

![](https://raw.githubusercontent.com/rbtnn/vim-near/main/near.gif)

## Installation

This is an example of installation using [vim-plug](https://github.com/junegunn/vim-plug).

```
Plug 'rbtnn/vim-near'
```

## Commands
### :Near [{directory}]
Open/Close a near window at {directory}. If {directory} is omited or invalid, use current directory.

## Variables
### g:near\_ignoredirs
This contains ignored directory names.
This default is `['node_modules', '.git', '.svn', '_svn']`.

### g:near\_maxdepth
This is the maxdepth.
This default is `2`.

