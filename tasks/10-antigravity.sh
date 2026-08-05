#!/usr/bin/env bash
# tasks/10-antigravity.sh - Antigravity and Jetski installations

# The specific version for Non-Work macOS IDE installations.
# Bump this string whenever you want to upgrade.
IDE_VERSION="2.5.0-5471848641724416"

# 1. Determine if sudo will be required, and refresh credentials in the foreground
# if needed, so both the checks and background spinners do not hang.
needs_sudo=false
if is_privileged && is_mac; then
    if is_work; then
        needs_sudo=true
    elif [ ! -d "/Applications/Antigravity.app" ] && [ ! -d "/Applications/Antigravity IDE.app" ]; then
        needs_sudo=true
    fi
fi

if [ "$needs_sudo" = true ]; then
    echo "--> Refreshing sudo credentials for Antigravity/Jetski installations..."
    sudo -v
fi

# 2. Jetski IDE & CLI (Work macOS Only - Requires Privileged)
if is_privileged && is_mac && is_work; then
    install_jetski_ide() {
        sudo mule install jetski
    }
    install_jetski_cli() {
        sudo mule install jetski-cli
    }

    if ! sudo mule check jetski 2>/dev/null | grep -q "found expected install"; then
        run_task "Install Jetski IDE via Mule" install_jetski_ide
    fi
    if ! sudo mule check jetski-cli 2>/dev/null | grep -q "found expected install"; then
        run_task "Install Jetski CLI via Mule" install_jetski_cli
    fi
fi

# 3. Antigravity IDE (Non-Work macOS Only - Requires Privileged)
if is_privileged && is_mac && ! is_work; then
    install_antigravity_ide() {
        local tmp_dir="${PYLOCAL:-${HOME}/.local}/tmp"
        mkdir -p "$tmp_dir"

        # Dynamically map architecture to eliminate version URL fragility
        local ide_arch="darwin-x64"
        [ "$(uname -m)" = "arm64" ] && ide_arch="darwin-arm"

        local url="https://storage.googleapis.com/antigravity-public/antigravity-hub/${IDE_VERSION}/${ide_arch}/Antigravity.dmg"
        local dmg_path="${tmp_dir}/Antigravity.dmg"

        curl -fsSL -o "$dmg_path" "$url" || return 1

        local mount_dir="/Volumes/Antigravity"
        hdiutil detach "$mount_dir" -force 2>/dev/null || true
        hdiutil attach -nobrowse -readonly "$dmg_path" >/dev/null || return 1

        # The app might be named Antigravity.app or Antigravity IDE.app
        sudo cp -R /Volumes/Antigravity/*.app /Applications/ || { hdiutil detach "$mount_dir" >/dev/null; return 1; }

        hdiutil detach "$mount_dir" >/dev/null
        rm -f "$dmg_path"
        return 0
    }

    if [ ! -d "/Applications/Antigravity.app" ] && [ ! -d "/Applications/Antigravity IDE.app" ]; then
        run_task "Install Antigravity IDE (DMG)" install_antigravity_ide
    fi
fi

# 4. Antigravity CLI (All hosts without Jetski, EXCEPT Work MacBooks)
# (Does not require Privileged, installs to user-space ~/.local/bin/)
if ! { is_mac && is_work; } && [ ! -d "/google" ] && ! command -v jetski-cli >/dev/null 2>&1 && ! command -v jetski >/dev/null 2>&1; then
    if ! command -v agy >/dev/null 2>&1; then
        run_task "Install Antigravity CLI" "curl -fsSL https://antigravity.google/cli/install.sh | bash"
    fi
fi
