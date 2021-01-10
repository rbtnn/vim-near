
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
### :Near [{directory}]
Open/Close a near window at {directory}. If {directory} is omited or invalid, use current directory.

__Keymappings in Near Buffer__

|Key        |Description                                              |
|-----------|---------------------------------------------------------|
|Enter      |Open a file or a directory under the cursor.             |
|Space      |Open a file or a directory under the cursor.             |
|L          |Open a file or a directory under the cursor.             |
|H          |Go up to parent directory.                               |
|C          |Change the current directory to the near's directory.    |
|~          |Change the current directory to Home directory.          |

## Variables
### g:near\_ignore
This contains ignored names.
This default is `['node_modules', '.git', '.svn', '_svn', '.dotnet', 'desktop.ini', 'System Volume Information', 'Thumbs.db']`.

