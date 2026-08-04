#!/usr/bin/env bash
# tasks/07-ssh.sh - SSH configuration, control channels, and X11 forwarding

if is_mac; then
    # Fix: Bug #3 - avoid executing which output as command
    if ! command -v xauth >/dev/null 2>&1; then
        run_task "Install XQuartz via Homebrew" brew install xquartz
    fi
fi
touch "${HOME}/.Xauthority"

setup_ssh_config() {
    install -d -m 0700 "${HOME}/.ssh"
    chmod 0700 "${HOME}/.ssh" # Ensure strict permissions even if it already existed

    install -d -m 0700 "${HOME}/.ssh/.control_channels"

    # Fix: Bug #3 - avoid executing grep output as command
    if ! grep -q "${SSHKEY}" "${HOME}/.ssh/authorized_keys" 2>/dev/null; then
        touch "${HOME}/.ssh/authorized_keys"
        chmod 0600 "${HOME}/.ssh/authorized_keys"
        echo "${SSHKEY}" >> "${HOME}/.ssh/authorized_keys"
    fi

    if [ ! -f "${HOME}/.ssh/config" ]; then
        echo 'ControlPath ~/.ssh/.control_channels/%C' > "${HOME}/.ssh/config"

        local xauth_path
        xauth_path=$(command -v xauth 2>/dev/null)
        if [ -n "$xauth_path" ]; then
            echo "XauthLocation $xauth_path" >> "${HOME}/.ssh/config"
        fi

        chmod 0600 "${HOME}/.ssh/config"
    fi
}

run_task "Configure SSH and Control Channels" setup_ssh_config
