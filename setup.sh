#!/bin/bash

if [ ! -e ${HOME}/.local ]; then
    if [ `uname -s` == "Darwin" ]; then
        PYVER=`python3 --version | cut -d ' ' -f 2`
        PYLOCAL="${HOME}/Library/Python/${PYVER}"
        ln -sf ${PYLOCAL} ${HOME}/.local
    else
        install -d ${HOME}/.local/tmp
    fi
fi

# Install Pygments
python3 -m pip install --user Pygments

# Install Pandoc
PANDOC_VER="3.1.8"
if [ `uname -s` == "Darwin" -a `uname -m` == "arm64" ]; then
    [ -f ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-arm64-macOS.zip ] && rm -f ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-arm64-macOS.zip
    curl -s -S -L -O --output-dir ${HOME}/.local/tmp --create-dirs https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-arm64-macOS.zip
    unzip -q ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-arm64-macOS.zip -d ${HOME}/.local
else
    [ -f ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-linux-amd64.tar.gz ] && rm -f ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-linux-amd64.tar.gz
    curl -s -S -L -O --output-dir ${HOME}/.local/tmp --create-dirs https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-linux-amd64.tar.gz
    tar zxf ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-linux-amd64.tar.gz -C ${HOME}/.local
fi

if [ -L ${HOME}/.local/pandoc ]; then
    unlink ${HOME}/.local/pandoc
    ln -sf ${HOME}/.local/pandoc-${PANDOC_VER} ${HOME}/.local/pandoc
elif [ -d ${HOME}/.local/pandoc ]; then
    echo "!!!!! ${HOME}/.local/pandoc exists. Moving out of the way. !!!!!"
    mv ${HOME}/.local/pandoc ${HOME}/.local/pandoc.old
    ln -sf ${HOME}/.local/pandoc-${PANDOC_VER} ${HOME}/.local/pandoc
elif [ -e ${HOME}/.local/pandoc ]; then
    echo "!!!!! ${HOME}/.local/pandoc exists. Unsure what to do. !!!!!"
elif [ ! -e ${HOME}/.local/pandoc ]; then
    ln -sf ${HOME}/.local/pandoc-${PANDOC_VER} ${HOME}/.local/pandoc
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
for dir in autoload bundle ftdetect ftplugin indent syntax; do
    install -d -o ${USER} ${HOME}/.vim/${dir}
done
pushd ${HOME}/.vim/bundle
for repo in https://github.com/VundleVim/Vundle.vim.git git://github.com/tpope/vim-bundler.git https://github.com/nvie/vim-flake8.git https://github.com/tpope/vim-pathogen.git git://github.com/tpope/vim-projectionist.git https://github.com/Vimjas/vim-python-pep8-indent.git git://github.com/tpope/vim-rails.git git://github.com/tpope/vim-rake.git; do
    git clone ${repo} 
done
popd
[ -f ${HOME}/.vimrc ] && cp ${HOME}/.vimrc ${HOME}/.vimcrc.bak
install -o ${USER} vimrc ${HOME}/.vimrc

# Instal rc files
[ -f ${HOME}/.bashrc ] && cp ${HOME}/.bashrc ${HOME}/.bashrc.bak
install -o ${USER} bashrc ${HOME}/.bashrc
[ -f ${HOME}/.bash_profile ] && cp ${HOME}/.bash_profile ${HOME}/.bash_profile.bak
install -o ${USER} bash_profile ${HOME}/.bash_profile
[ -f ${HOME}/.lessfilter ] && cp ${HOME}/.lessfilter ${HOME}/.lessfilter.bak
install -o ${USER} lessfilter ${HOME}/.lessfilter
