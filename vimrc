" enable vim-pathogen
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

call plug#begin()
Plug 'wojciechkepka/vim-github-dark'
call plug#end()

set nocompatible
filetype plugin indent on
set nohlsearch
set bg=dark
colorscheme ghdark
set pastetoggle=<F12>
set bs=2
syntax on
set ruler
set paste
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab
set backupdir=/tmp
set directory=/tmp
set mouse-=a
