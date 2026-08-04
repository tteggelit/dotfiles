#!/usr/bin/env bash
# tasks/01-git.sh - Git configuration and SSH signing support

setup_git() {
    local REQUIRED_MAJOR=2
    local REQUIRED_MINOR=34

    local INSTALLED_VERSION
    INSTALLED_VERSION=$(git --version | awk '{print $3}')
    local INSTALLED_MAJOR=$(echo "$INSTALLED_VERSION" | cut -d. -f1)
    local INSTALLED_MINOR=$(echo "$INSTALLED_VERSION" | cut -d. -f2)

    local SSH_SIGNING_SUPPORTED="no"
    if command -v ssh-keygen >/dev/null 2>&1; then
        # ssh-keygen outputs its usage to stderr when given an unknown flag or empty -Y
        if ssh-keygen -Y sign 2>&1 | grep -q "unknown option"; then
            SSH_SIGNING_SUPPORTED="no"
        else
            SSH_SIGNING_SUPPORTED="yes"
        fi
    fi

    # Enforce base configurations
    [ "$(git config --global --get user.name)" != "Ti Leggett" ] && git config --global user.name "Ti Leggett"
    [ "$(git config --global --get pull.rebase)" != "false" ] && git config --global pull.rebase "false"
    [ "$(git config --global --get user.email)" != "${EMAIL}" ] && git config --global user.email "${EMAIL}"

    # Fix: Bug #3 - avoid executing the output of grep as a command
    if ! grep -q ".vscode/" "${HOME}/.gitignore_global" 2>/dev/null; then
        echo ".vscode/" >> "${HOME}/.gitignore_global"
        [ "$(git config --global --get core.excludefiles)" != "${HOME}/.gitignore_global" ] && git config --global core.excludesfile "${HOME}/.gitignore_global"
    fi

    local GIT_VERSION_VALID=0
    if (( INSTALLED_MAJOR > REQUIRED_MAJOR )) || (( INSTALLED_MAJOR == REQUIRED_MAJOR && INSTALLED_MINOR >= REQUIRED_MINOR )); then
        GIT_VERSION_VALID=1
    fi

    if [ "$GIT_VERSION_VALID" -eq 1 ] && [ "$SSH_SIGNING_SUPPORTED" = "yes" ]; then
        # Enable signing
        [ "$(git config --global --get user.signingkey)" != "${SSHKEY}" ] && git config --global user.signingkey "${SSHKEY}"
        [ "$(git config --global --get gpg.format)" != "ssh" ] && git config --global gpg.format "ssh"
        [ "$(git config --global --get commit.gpgsign)" != "true" ] && git config --global commit.gpgsign "true"

        local op_sign="/Applications/1Password.app/Contents/MacOS/op-ssh-sign"
        if is_mac && [ -x "$op_sign" ]; then
            [ "$(git config --global --get gpg.ssh.program)" != "$op_sign" ] && git config --global gpg.ssh.program "$op_sign"
        fi
    else
        echo "SSH commit signing is not supported on this platform (Missing Git 2.34+ or OpenSSH 8.2+). Disabling signing."
        [ "$(git config --global --get commit.gpgsign)" = "true" ] && git config --global commit.gpgsign "false"
        git config --global --unset user.signingkey 2>/dev/null
        git config --global --unset gpg.format 2>/dev/null
        git config --global --unset gpg.ssh.program 2>/dev/null
    fi
}

run_task "Configure Git and SSH signing" setup_git
