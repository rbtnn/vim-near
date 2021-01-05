
# vim-near
[![vim](https://github.com/rbtnn/vim-near/workflows/vim/badge.svg)](https://github.com/rbtnn/vim-near/actions?query=workflow%3Avim)
[![neovim](https://github.com/rbtnn/vim-near/workflows/neovim/badge.svg)](https://github.com/rbtnn/vim-near/actions?query=workflow%3Aneovim)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

This plugin provides to select a file.
This plugin is like [preservim/nerdtree](https://github.com/preservim/nerdtree).

![](https://raw.githubusercontent.com/rbtnn/vim-near/main/near.gif)

## Installation

This is an example of installation using [vim-plug](https://github.com/junegunn/vim-plug).

```
Plug 'rbtnn/vim-near'
```

## Commands
### :[{maxdepth}]Near [{directory}]
Open/Close a near window at {directory}. If {directory} is omited or invalid, use current directory.
{maxdepth} is the maximum number of levels of directories to visit for display.

## Variables
### g:near\_ignore
This contains ignored directory names.
This default is `['node_modules', '.git', '.svn', '_svn', '.dotnet', 'desktop.ini']`.

