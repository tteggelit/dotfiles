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
"set paste
set bs=2
syntax on
set ruler
set autoindent
set shiftwidth=4
set tabstop=4
set softtabstop=4
set expandtab
" Override for YAML
autocmd FileType yaml
    \ setlocal shiftwidth=2
    \ tabstop=2
    \ softtabstop=2
set backupdir=/tmp
set directory=/tmp
set mouse-=a
