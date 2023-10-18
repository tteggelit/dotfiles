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
if [ `uname -s` == "Darwin" && `uname -m` == "arm64" ]; then
    curl -O --output-dir ${HOME}/.local/tmp --create-dirs https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-arm64-macOS.zip
    unzip ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-arm64-macOS.zip -d ${HOME}/.local
else
    curl -O --output-dir ${HOME}/.local/tmp --create-dirs https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-linux-amd64.tar.gz
    tar zxvf ${HOME}/.local/tmp/pandoc-${PANDOC_VER}-linux-amd64.tar.gz -C ${HOME}/.local
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
