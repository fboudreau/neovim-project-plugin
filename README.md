


A neovim plugin to manage projects. The following features are provided:

This plugin essentially keeps track of a given project root directory and uses
that information to easily create tag files, open NERDtree from the root, 
automatically search using Ack from the root, etc.

The following mappings are used:

<leader>ap to search for a project file and open it
<leader>aa Present Ack and launch the search from the root of the project
<leader>at Generate a tags (ctags) file from the root of the project.
<ctrl-n> Open NERDtree from root of the project.

## Dependencies

- neovim +ruby
- Plugin 'mileszs/ack.vim'
- Plugin 'scrooloose/nerdtree'
- ctags
- find

## Installation

Using [Vundle](https://github.com/VundleVim/Vundle.vim)

```vim
Plugin 'fboudreau/neovim-project-plugin'
Plugin 'mileszs/ack.vim'
Plugin 'scrooloose/nerdtree'
```


