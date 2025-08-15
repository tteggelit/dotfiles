#!/usr/bin/env bash

# Install Homebrew (macOS)
if [ `uname -s` == "Darwin" ]; then
    if $( ! `which -s brew` ); then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

# Install Terminal Defaults (macOS)
if [ `uname -s` == "Darwin" ]; then
    TERM_DEFAULTS=`defaults write com.apple.Terminal "Default Window Settings"`
    if [ "${TERM_DEFAULTS}" != "Github Dark" ]; then
        open "Github Dark.terminal"
        defaults write com.apple.Terminal "Default Window Settings" -string "Github Dark"
        defaults write com.apple.Terminal "Startup Window Settings" -string "Github Dark"
    fi
fi

if ((BASH_VERSINFO < 4 )); then
    echo "Current running bash version is not greater than 4."
    if [ `uname -s` == "Darwin" ]; then
        echo "Installing newer bash via Homebrew."
        echo "After installation, edit Terminal settings to use newly isntalled bash."
        brew install bash
    fi
    echo "Exiting."
    exit 1
fi

PYUSERBASE=`python3 -c "import site; print(site.USER_BASE)"`
PYLOCAL=${HOME}/.local
if [ ! -e ${PYLOCAL} ]; then
    if [ `uname -s` == "Darwin" ]; then
        [ ! -d ${PYUSERBASE} ] && install -d ${PYUSERBASE}
        ln -sf ${PYUSERBASE} ${PYLOCAL}
    else
        install -d ${PYLOCAL}
    fi
fi
install -d ${PYLOCAL}/tmp

# Install flake8
if $( ! `which -s flake8` ); then
    if [ `uname -s` == "Darwin" ]; then
        brew install flake8
    else
        python3 -m pip install --user flake8
    fi
fi


# Install Pygments
if $( ! `which -s pygmentize` ); then
    if [ `uname -s` == "Darwin" ]; then
        brew install pygments
    else
        python3 -m pip install --user Pygments
    fi
fi

# Install Pandoc
if $( ! `which -s pygmentize` ); then
    if [ `uname -s` == "Darwin" ]; then
        brew install groff pandoc
    else
        PANDOC_VER="3.1.8"
        pushd ${PYLOCAL}/tmp
        [ -f ${PYLOCAL}/tmp/pandoc-${PANDOC_VER}-linux-amd64.tar.gz ] && rm -f ${PYLOCAL}/tmp/pandoc-${PANDOC_VER}-linux-amd64.tar.gz
        curl -s -S -L -O https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-linux-amd64.tar.gz
        tar zxf pandoc-${PANDOC_VER}-linux-amd64.tar.gz -C ${PYLOCAL}
        rm -f pandoc-${PANDOC_VER}-linux-amd64.tar.gz
        popd
        
        if [ -L ${PYLOCAL}/pandoc ]; then
            unlink ${PYLOCAL}/pandoc
            ln -sf ${PYLOCAL}/pandoc-${PANDOC_VER} ${PYLOCAL}/pandoc
        elif [ -d ${PYLOCAL}/pandoc ]; then
            echo "!!!!! ${PYLOCAL}/pandoc exists. Moving out of the way. !!!!!"
            mv ${PYLOCAL}/pandoc ${PYLOCAL}/pandoc.old
            ln -sf ${PYLOCAL}/pandoc-${PANDOC_VER} ${PYLOCAL}/pandoc
        elif [ -e ${PYLOCAL}/pandoc ]; then
            echo "!!!!! ${PYLOCAL}/pandoc exists. Unsure what to do. !!!!!"
        elif [ ! -e ${PYLOCAL}/pandoc ]; then
            ln -sf ${PYLOCAL}/pandoc-${PANDOC_VER} ${PYLOCAL}/pandoc
        fi
    fi
fi

# Install Bash-it
if [ ! -d ${HOME}/.bash_it ]; then
    git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
    ${HOME}/.bash_it/install.sh --silent --no-modify-config
    source ${HOME}/.bash_it/bash_it.sh
    bash-it enable plugin base git man ssh
    [ `uname -s` == "Darwin" ] && bash-it enable plugin osx
    bash-it enable alias general git vim
    [ `uname -s` == "Darwin" ] && bash-it enable alias homebrew osx
fi

# Configure Vim
# Make sure all the necessary directories exist
for dir in autoload bundle ftdetect ftplugin indent syntax; do
    install -d -o ${USER} ${HOME}/.vim/${dir}
done

# Download all the Vim bundles
pushd ${HOME}/.vim/bundle
declare -A repos
repos[Vundle.vim]="https://github.com/VundleVim/Vundle.vim.git"
repos[vim-bundler]="https://github.com/tpope/vim-bundler.git"
repos[vim-flake8]="https://github.com/nvie/vim-flake8.git"
repos[vim-pathogen]="https://github.com/tpope/vim-pathogen.git"
repos[vim-projectionist]="https://github.com/tpope/vim-projectionist.git"
repos[vim-python-pep8-indent]="https://github.com/Vimjas/vim-python-pep8-indent.git"
repos[vim-rails]="https://github.com/tpope/vim-rails.git"
repos[vim-rake]="https://github.com/tpope/vim-rake.git"
repos[vim-plug]="https://github.com/junegunn/vim-plug.git"

for repo in ${!repos[@]}; do
    if [ -d ${repo} ]; then
        pushd ${repo}
        git pull
        popd
    else
        git clone ${repos[${repo}]} 
    fi
done
popd

# If the Plug isn't set to autoload, make it so
[ ! -e ${HOME}/.vim/autoload/plug.vim ] && ln -sf ${HOME}/.vim/bundle/vim-plug/plug.vim ${HOME}/.vim/autoload/plug.vim

[ -f ${HOME}/.vimrc ] && cp ${HOME}/.vimrc ${HOME}/.vimcrc.bak
install -o ${USER} vimrc ${HOME}/.vimrc
vim +PlugInstall +qall

# Instal rc files
[ -f ${HOME}/.bashrc ] && cp ${HOME}/.bashrc ${HOME}/.bashrc.bak
install -o ${USER} bashrc ${HOME}/.bashrc
[ -f ${HOME}/.bash_profile ] && cp ${HOME}/.bash_profile ${HOME}/.bash_profile.bak
install -o ${USER} bash_profile ${HOME}/.bash_profile
[ -f ${HOME}/.lessfilter ] && cp ${HOME}/.lessfilter ${HOME}/.lessfilter.bak
install -o ${USER} lessfilter ${HOME}/.lessfilter

[ -d ${PYLOCAL}/tmp ] && rm -rf ${PYLOCAL}/tmp
