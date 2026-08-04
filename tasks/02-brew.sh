#!/usr/bin/env bash
# tasks/02-brew.sh - Homebrew and Terminal defaults (macOS only)

is_mac || return 0

# Install Homebrew
if ! command -v brew >/dev/null 2>&1; then
    run_task "Install Homebrew" '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
fi

# Configure Terminal Defaults
setup_terminal() {
    # Fix: Bug #6 - Use absolute path to the dotfiles directory
    local theme_file="${DOTFILES_DIR}/Github Dark.terminal"

    if [ -f "$theme_file" ] && [ "$(defaults read com.apple.Terminal "Default Window Settings" 2>/dev/null)" != "Github Dark" ]; then
        open "$theme_file"
        defaults write com.apple.Terminal "Default Window Settings" -string "Github Dark"
        defaults write com.apple.Terminal "Startup Window Settings" -string "Github Dark"
        defaults write com.apple.Terminal CopyAttributesProfile com.apple.Terminal.no-attributes
    fi
}
run_task "Configure Terminal Defaults" setup_terminal

# Check Bash version and upgrade if necessary
if (( BASH_VERSINFO <= 4 )); then
    new_bash="/usr/local/bin/bash"
    [ "$(uname -m)" = "arm64" ] && new_bash="/opt/homebrew/bin/bash"

    if [ -x "$new_bash" ]; then
        echo -e "${YELLOW}Notice: A newer Bash is installed at $new_bash, but your current session is not using it."
        echo -e "Please edit your Terminal settings (or run 'chsh -s $new_bash') to make it your default shell.${NC}"
    else
        echo -e "${YELLOW}Current running bash version is too old (${BASH_VERSION})."
        echo "Installing newer bash via Homebrew..."
        run_task "Install newer Bash via Homebrew" brew install bash bash-completion@2
        echo -e "After installation, run 'chsh -s $new_bash' and restart your terminal.${NC}"
    fi
fi
