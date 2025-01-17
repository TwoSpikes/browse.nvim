# Browse.nvim

Browser plug-in for NeoVim

# Supported features

- `<strong>`
- `<i>`

# Installation

Using [lazy.vim](https://github.com/folke/lazy.nvim):
```lua
{
  "TwoSpikes/browse.nvim",
}
```

Using [vim-plug](https://github.com/junegunn/vim-plug):
```vim
Plug 'TwoSpikes/browse.nvim'
```

Using [packer.nvim](https://github.com/wbthomason/packer.nvim):
```lua
use {
    'TwoSpikes/browse.nvim',
}
```

Using [pckr.nvim](https://github.com/lewis6991/pckr.nvim):
```lua
{
    'TwoSpikes/browse.nvim',
}
```

Using [dein](https://github.com/Shougo/dein.vim):
```vim
call dein#add('TwoSpikes/browse.nvim')
```

Using [paq-nvim](https://github.com/savq/paq-nvim):
```lua
'TwoSpikes/browse.nvim',
```

Using [Pathogen](https://github.com/tpope/vim-pathogen):
```console
$ cd ~/.vim/bundle
$ git clone --depth=1 https://github.com/TwoSpikes/browse.nvim
```

Using Vim built-in package manager (requires Vim v.8.0+) ([help](https://vimhelp.org/repeat.txt.html#packages) or `:h packages`):
```console
$ cd ~/.vim/pack/test/start/
$ git clone --depth=1 https://github.com/TwoSpikes/browse.nvim
```

# How to use it

## Browse from file

```
:call browse#setup()
:call browse#open_file('path/to/file')
```

## Browse from string

```
:call browse#setup()
:call browse#open_page('Some string')
```
