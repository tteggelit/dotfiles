#!/usr/bin/env bash
# tasks/05-vim.sh - Vim bundles and configuration

setup_vim_base() {
    # Ensure directories exist
    for dir in autoload bundle ftdetect ftplugin indent syntax; do
        install -d -o "${USER}" -m 0755 "${HOME}/.vim/${dir}"
    done

    # Symlink vimrc instead of diff/copy to avoid CWD issues and keep in sync
    symlink_file "${DOTFILES_DIR}/vimrc" "${HOME}/.vimrc"

    # Safely symlink plug.vim if the bundle exists
    if [ -f "${HOME}/.vim/bundle/vim-plug/plug.vim" ]; then
        symlink_file "${HOME}/.vim/bundle/vim-plug/plug.vim" "${HOME}/.vim/autoload/plug.vim"
    fi
}
run_task "Configure Vim base and symlink vimrc" setup_vim_base

update_vim_bundles() {
    local bundle_dir="${HOME}/.vim/bundle"
    mkdir -p "$bundle_dir"

    local repos=(
        "https://github.com/VundleVim/Vundle.vim.git"
        "https://github.com/tpope/vim-bundler.git"
        "https://github.com/nvie/vim-flake8.git"
        "https://github.com/tpope/vim-pathogen.git"
        "https://github.com/tpope/vim-projectionist.git"
        "https://github.com/Vimjas/vim-python-pep8-indent.git"
        "https://github.com/tpope/vim-rails.git"
        "https://github.com/tpope/vim-rake.git"
        "https://github.com/junegunn/vim-plug.git"
    )

    for url in "${repos[@]}"; do
        local name
        name=$(basename "$url" .git)
        echo "Updating $name..."
        git_clone_or_pull "$url" "${bundle_dir}/${name}"
    done

    # Ensure plug.vim is linked now that it has been cloned (for first-time installs)
    if [ -f "${bundle_dir}/vim-plug/plug.vim" ]; then
        symlink_file "${bundle_dir}/vim-plug/plug.vim" "${HOME}/.vim/autoload/plug.vim"
    fi
}
run_task "Update Vim Pathogen bundles" update_vim_bundles

if command -v vim >/dev/null 2>&1; then
    # Fix: Reverted to the original exact invocation. Standard Vim handles redirected
    # output perfectly, whereas -E -s (silent batch mode) broke Vim-Plug window splitting.
    run_task "Install Vim-Plug plugins" "vim +PlugInstall +qall"
fi
