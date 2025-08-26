#!/usr/bin/env bash

HOME_EMAIL="ti@daleggetts.com"
HOME_SSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMOKogNrOncCCAKczMINsi5rKoOOEEqLB+9bcNpzuDf"
WORK_EMAIL="tileggett@nvidia.com"
WORK_SSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILvHbsE42CseuVtkD/FkLexiQq3Z5sanlXZWnizTSzCi"

PROFILE="home"
EMAIL=${HOME_EMAIL}
SSHKEY=${HOME_SSHKEY}

while getopts "w" opt; do
    case ${opt} in
        w)
            PROFILE="work"
            EMAIL=${WORK_EMAIL}
            SSHKEY=${WORK_SSHKEY}
            ;;
        *)
            PROFILE="home"
            EMAIL=${HOME_EMAIL}
            SSHKEY=${HOME_SSHKEY}
            ;;
    esac
done

# Git configuration
REQUIRED_MAJOR=2
REQUIRED_MINOR=34

# Get installed Git version
# Git signing was first instroduced in v2.34
INSTALLED_VERSION=$(git --version | awk '{print $3}')
INSTALLED_MAJOR=$(echo "$INSTALLED_VERSION" | cut -d. -f1)
INSTALLED_MINOR=$(echo "$INSTALLED_VERSION" | cut -d. -f2)

# Compare versions
[ "`git config --global --get user.name`" != "Ti Leggett" ] && git config --global user.name "Ti Leggett"
[ "`git config --global --get pull.rebase`" != "false" ] && git config --global pull.rebase "false"
[ "`git config --global --get user.email`" != "${EMAIL}" ] && git config --global user.email "${EMAIL}"
if (( INSTALLED_MAJOR > REQUIRED_MAJOR )) || \
   (( INSTALLED_MAJOR == REQUIRED_MAJOR && INSTALLED_MINOR >= REQUIRED_MINOR )); then
    [ "`git config --global --get user.signingkey`" != "${SSHKEY}" ] && git config --global user.signingkey "${SSHKEY}"
    [ "`git config --global --get gpg.format`" != "ssh" ] && git config --global gpg.format "ssh"
    [ "`git config --global --get commit.gpgsign`" != "true" ] && git config --global commit.gpgsign "true"
    [ `uname -s` = "Darwin" -a "`git config --global --get gpg.ssh.program`" != "/Applications/1Password.app/Contents/MacOS/op-ssh-sign" ] && git config --global gpg.ssh.program "/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
fi

# Install Homebrew (macOS)
if [ `uname -s` = "Darwin" ]; then
    if $( ! `which brew > /dev/null 2>&1` ); then
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
fi

# Install Terminal Defaults (macOS)
if [ `uname -s` = "Darwin" ]; then
    if [ "`defaults read com.apple.Terminal "Default Window Settings"`" != "Github Dark" ]; then
        open "Github Dark.terminal"
        defaults write com.apple.Terminal "Default Window Settings" -string "Github Dark"
        defaults write com.apple.Terminal "Startup Window Settings" -string "Github Dark"
    fi
fi

if ((BASH_VERSINFO < 4 )); then
    echo "Current running bash version is not greater than 4."
    if [ `uname -s` = "Darwin" ]; then
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
    if [ `uname -s` = "Darwin" ]; then
        [ ! -d ${PYUSERBASE} ] && install -d ${PYUSERBASE}
        ln -sf ${PYUSERBASE} ${PYLOCAL}
    else
        install -d ${PYLOCAL}
    fi
fi
install -d ${PYLOCAL}/tmp

# Install flake8
if $( ! `which flake8 > /dev/null 2>&1` ); then
    if [ `uname -s` = "Darwin" ]; then
        brew install flake8
    else
        python3 -m pip install --user flake8
    fi
fi


# Install Pygments
if $( ! `which pygmentize > /dev/null 2>&1` ); then
    if [ `uname -s` = "Darwin" ]; then
        brew install pygments
    else
        python3 -m pip install --user Pygments
    fi
fi

# Install Pandoc
if $( ! `which pandoc > /dev/null 2>&1` ); then
    if [ `uname -s` = "Darwin" ]; then
        brew install groff pandoc
    else
        case `uname -m` in
            "x86_64")
                PANDOC_ARCH="amd64"
                ;;
            "aarch64")
                PANDOC_ARCH="arm64"
                ;;
            *)
                PANDOC_ARCH="unknown"
                ;;
        esac
        if [ ${PANDOC_ARCH} != "unknown" ]; then
            PANDOC_VER="3.1.8"
            pushd ${PYLOCAL}/tmp
            [ -f ${PYLOCAL}/tmp/pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz ] && rm -f ${PYLOCAL}/tmp/pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz
            curl -s -S -L -O https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz
            tar zxf pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz -C ${PYLOCAL}
            rm -f pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz
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
            [ ! -L ${PYLOCAL}/bin/pandoc ] && ln -sf ${PYLOCAL}/pandoc/bin/pandoc ${PYLOCAL}/bin/pandoc
            [ ! -d ${PYLOCAL}/share/man -o ! -d ${PYLOCAL}/share/man/man1 ] && install -d ${PYLOCAL}/share/man/man1
            [ ! -L ${PYLOCAL}/share/man/man1/pandoc.1.gz ] && ln -sf ${PYLOCAL}/pandoc/share/man/man1/pandoc.1.gz ${PYLOCAL}/share/man/man1/pandoc.1.gz
        else
            echo "There isn't a prebuilt pandoc binary for this architecture. Install pandoc manually."
        fi
    fi
fi

# Install Bash-it
if [ ! -d ${HOME}/.bash_it ]; then
    git clone --depth=1 https://github.com/Bash-it/bash-it.git ~/.bash_it
    ${HOME}/.bash_it/install.sh --silent --no-modify-config
    source ${HOME}/.bash_it/bash_it.sh
    bash-it enable plugin base git man ssh
    [ `uname -s` = "Darwin" ] && bash-it enable plugin osx
    bash-it enable alias general git vim
    [ `uname -s` = "Darwin" ] && bash-it enable alias homebrew osx
    [ `uname -s` = "Linux" ] && bash-it enable alias systemd
    [ ${PROFILE} = "work" ] && bash-it enable alias vault
    bash-it enable completion git pip pip3 pipx ssh
    [ `uname -s` = "Darwin" ] && bash-it enable completion brew
    [ ${PROFILE} = "work" ] && bash-it enable completion vault
    bash-it reload
fi

# Configure Vim
# Make sure all the necessary directories exist
for dir in autoload bundle ftdetect ftplugin indent syntax; do
    install -d -o ${USER} -m 0755 ${HOME}/.vim/${dir}
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

echo "Checking for differences of ${HOME}/.vimrc..."
diff -u vimrc ${HOME}/.vimrc
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.vimrc. Refer to above for differences."
    [ -f ${HOME}/.vimrc ] && cp ${HOME}/.vimrc ${HOME}/.vimcrc.bak
    install -o ${USER} -m 0644 vimrc ${HOME}/.vimrc
    vim +PlugInstall +qall
fi

# Instal rc files
echo "Checking for differences of ${HOME}/.bashrc..."
diff -u bashrc ${HOME}/.bashrc
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.bashrc. Refer to above for differences."
    [ -f ${HOME}/.bashrc ] && cp ${HOME}/.bashrc ${HOME}/.bashrc.bak
    install -o ${USER} -m 0644 bashrc ${HOME}/.bashrc
fi

echo "Checking for differences of ${HOME}/.bash_profile..."
diff -u bash_profile ${HOME}/.bash_profile
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.bash_profile. Refer to above for differences."
    [ -f ${HOME}/.bash_profile ] && cp ${HOME}/.bash_profile ${HOME}/.bash_profile.bak
    install -o ${USER} -m 0644 bash_profile ${HOME}/.bash_profile
fi

echo "Checking for differences of ${HOME}/.lessfilter..."
diff -u lessfilter ${HOME}/.lessfilter
rc=$?
if [ ${rc} -ne 0 ]; then
    echo "Installing new ${HOME}/.lessfilter. Refer to above for differences."
    [ -f ${HOME}/.lessfilter ] && cp ${HOME}/.lessfilter ${HOME}/.lessfilter.bak
    install -o ${USER} -m 0755 lessfilter ${HOME}/.lessfilter
fi

# Install XQuartz
if [ `uname -s` = "Darwin" ]; then
    if $( ! `which xauth > /dev/null 2>&1` ); then
        echo "XQuartz not found. Installing XQuartz..."
        brew install xquartz
        if [ `uname -m` == "arm64" ]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
fi
touch ${HOME}/.Xauthority

# Configure SSH
[ ! -d ${HOME}/.ssh ] && install -d -m 0700 ${HOME}/.ssh
[ ! -d ${HOME}/.ssh/.control_channels ] && install -d -m 0700 ${HOME}/.ssh/.control_channels
[ ! -f ${HOME}/.ssh/authorized_keys ] && touch ${HOME}/.ssh/authorized_keys && chmod 0600 ${HOME}/.ssh/authorized_keys && echo "${SSHKEY}" > ${HOME}/.ssh/authorized_keys
if [ ! -f ${HOME}/.ssh/config ]; then
    echo 'ControlPath ~/.ssh/.control_channels/%h:%p:%r' > ${HOME}/.ssh/config
    if $( `which xauth > /dev/null 2>&1` ); then
        echo "XauthLocation `which xauth`" >> ${HOME}/.ssh/config
    fi
    chmod 0600 ${HOME}/.ssh/config
fi

# Slurm Configuration
if [ ${PROFILE} = "work" ]; then
    install -d ${HOME}/.vim/after/syntax/sh
    curl --silent --remote-name https://raw.githubusercontent.com/SchedMD/slurm/refs/heads/master/contribs/slurm_completion_help/slurm.vim --output-dir ${HOME}/.vim/after/syntax/sh/
    curl --silent --output ${HOME}/.slurm_completion.sh https://raw.githubusercontent.com/SchedMD/slurm/refs/heads/master/contribs/slurm_completion_help/slurm_completion.sh
fi

[ -d ${PYLOCAL}/tmp ] && rm -rf ${PYLOCAL}/tmp
