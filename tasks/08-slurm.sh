#!/usr/bin/env bash
# tasks/08-slurm.sh - Slurm syntax and completion downloads

is_work && is_slurm || return 0

setup_slurm() {
    install -d "${HOME}/.vim/after/syntax/sh"
    # Added -L to safely follow redirects
    curl -s -f -L -o "${HOME}/.vim/after/syntax/sh/slurm.vim" https://raw.githubusercontent.com/SchedMD/slurm/refs/heads/master/contribs/slurm_completion_help/slurm.vim || return 1
    curl -s -f -L -o "${HOME}/.slurm_completion.sh" https://raw.githubusercontent.com/SchedMD/slurm/refs/heads/master/contribs/slurm_completion_help/slurm_completion.sh || return 1
}

run_task "Download Slurm Vim syntax and Bash completions" setup_slurm
