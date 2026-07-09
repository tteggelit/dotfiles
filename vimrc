" enable vim-pathogen
runtime bundle/vim-pathogen/autoload/pathogen.vim
execute pathogen#infect()

call plug#begin()
Plug 'wojciechkepka/vim-github-dark'
call plug#end()

set nocompatible
filetype plugin indent on
syntax on
set bg=dark
colorscheme ghdark
set nohlsearch
" Highlight trailing whitespace (defined AFTER the colorscheme)
highlight ExtraWhitespace ctermbg=red guibg=red

" Automatically match trailing whitespace in all windows, skipping terminal buffers
autocmd VimEnter,WinEnter * if &buftype != 'terminal' | match ExtraWhitespace /\s\+$/ | endif

set pastetoggle=<F12>
"set paste
set bs=2
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
