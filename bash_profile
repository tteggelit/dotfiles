#!/usr/bin/env bash

# If not running interactively, don't do anything
case $- in
  *i*) ;;
    *) return;;
esac

#set -xv

[ -f /etc/profile ] && source /etc/profile
[ -f ${HOME}/.bashrc ] && source ${HOME}/.bashrc

#TERM=xterm-color


####
# Local paths
#
PATH=${PATH}:${HOME}/.local/bin:${HOME}/.local/pandoc/bin
MANPATH=${MANPATH}:${HOME}/.local/share/man:${HOME}/.local/pandoc/share/man
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:${HOME}/local/lib
export PATH MANPATH LD_LIBRARY_PATH


####
# Configure Vim
#
if ! $( which vim 2>&1 > /dev/null ); then alias vim=`which vi`; fi
export EDITOR=vim
alias vi='echo "Use vim"'


####
# Configure prompt
#
PS1="\n\[\033[01;36m\]\d \@\n\[\033[01;35m\][\[\033[01;32m\]\u@\h:\[\033[01;36m\]\w\[\033[01;35m\]]\$\[\033[01;00m\] "
#PS1="\n\[\033[01;36m\]\d \@\n[\[\033[01;32m\]\u@\h:\[\033[01;34m\]\w\[\033[01;36m\]]\$\[\033[01;00m\] "
export PS1


####
# Configure less
#
export LESS='-R'
export LESSOPEN='|~/.lessfilter %s'


####
# Configure history
#
HISTCONTROL=ignorespace
HISTSIZE=10000
export HISTCONTROL HISTSIZE
shopt -s histappend
export PROMPT_COMMAND="history -a; history -r; $PROMPT_COMMAND"

if [[ -f ~/.dircolors ]]; then
    eval `dircolors ~/.dircolors`
fi


####
# Configure Homebrew
#
# Homebrew GitHub token
# export HOMEBREW_GITHUB_API_TOKEN="16eab4aa3f07289741fda2d8b1a3d344fd28d0a1"
if [ `uname -s` = "Darwin" ]; then
    export HOMEBREW_GITHUB_API_TOKEN="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" # No longer valid
    if [ `uname -m` = "arm64" ]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    else
        eval "$(/usr/local/bin/brew shellenv)"
    fi
fi

##
# Configure bash_completion
#
if [ `uname -s` = "Darwin" ]; then
    [ -f ${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh ] && . ${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh
fi

####
# Configure Bash-it
#
# Path to the bash it configuration
export BASH_IT="${HOME}/.bash_it"

# Lock and Load a custom theme file
# location /.bash_it/themes/
# export BASH_IT_THEME='bobby'
export BASH_IT_THEME=""

# Your place for hosting Git repos. I use this for private repos.
# export GIT_HOSTING='git@git.domain.com'

# Don't check mail when opening terminal.
unset MAILCHECK

# Change this to your console based IRC client of choice.
export IRC_CLIENT='irssi'

# Set this to the command you use for todo.txt-cli
export TODO="t"

# Set this to false to turn off version control status checking within the prompt for all themes
export SCM_CHECK=false

# Set vcprompt executable path for scm advance info in prompt (demula theme)
# https://github.com/xvzf/vcprompt
#export VCPROMPT_EXECUTABLE=~/.vcprompt/bin/vcprompt

# Load Bash It
source "$BASH_IT"/bash_it.sh

# Load Slurm completions
[ -f ${HOME}/.slurm_completion.sh ] && source ${HOME}/.slurm_completion.sh

####
# Configure general overrides
#
if [ `uname -s` = "Linux" ]; then
    alias ls='ls --color --classify'
elif [ `uname -s` = "Darwin" ]; then
    alias ls='ls -F -G'
fi
