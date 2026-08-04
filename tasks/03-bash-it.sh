#!/usr/bin/env bash
# tasks/03-bash-it.sh - Bash-it installation and configuration

if [ ! -d "${HOME}/.bash_it" ]; then
    run_task "Clone Bash-it" git clone --depth=1 https://github.com/Bash-it/bash-it.git "${HOME}/.bash_it"
    run_task "Install Bash-it" "${HOME}/.bash_it/install.sh --silent --no-modify-config"
fi

if [ -d "${HOME}/.bash_it" ]; then
    # Symlink our new version-controlled custom files to your existing Bash-it structure.
    # The symlink_file helper will automatically back up your old appended files to .bak!
    run_task "Deploy custom aliases" symlink_file "${DOTFILES_DIR}/config/bash_it/aliases.bash" "${HOME}/.bash_it/aliases/custom.aliases.bash"
    run_task "Deploy custom completions" symlink_file "${DOTFILES_DIR}/config/bash_it/completions.bash" "${HOME}/.bash_it/completion/custom.completions.bash"

    configure_bash_it() {
        # Since your version of Bash-it uses a shell function, we MUST source the
        # framework here in the subshell to make the `bash-it` command available.
        export BASH_IT="${HOME}/.bash_it"
        export BASH_IT_THEME=""
        source "${BASH_IT}/bash_it.sh"

        # Plugins
        bash-it enable plugin base git man ssh
        is_mac && bash-it enable plugin osx
        is_work && bash-it enable plugin tmux

        # Aliases
        bash-it enable alias general git vim
        is_mac && bash-it enable alias homebrew osx
        is_linux && bash-it enable alias systemd
        is_work && bash-it enable alias tmux

        # Completions
        bash-it enable completion git pip pip3 pipx ssh
        is_mac && bash-it enable completion brew
        is_work && command -v gcloud >/dev/null 2>&1 && bash-it enable completion gcloud
        bash-it enable completion tmux
    }

    run_task "Configure Bash-it components" configure_bash_it
fi
