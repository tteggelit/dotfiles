#!/usr/bin/env bash
# tasks/06-rc-files.sh - Symlink remaining runtime configuration files

link_rc_files() {
    symlink_file "${DOTFILES_DIR}/bashrc" "${HOME}/.bashrc"
    symlink_file "${DOTFILES_DIR}/bash_profile" "${HOME}/.bash_profile"

    # Ensure the source is executable before linking
    chmod +x "${DOTFILES_DIR}/lessfilter"
    symlink_file "${DOTFILES_DIR}/lessfilter" "${HOME}/.lessfilter"

    symlink_file "${DOTFILES_DIR}/screenrc" "${HOME}/.screenrc"
    symlink_file "${DOTFILES_DIR}/tmux.conf" "${HOME}/.tmux.conf"
}

run_task "Symlink runtime configuration (RC) files" link_rc_files
