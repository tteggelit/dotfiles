#!/usr/bin/env bash
# tasks/00-preflight.sh - Cache credentials and check basic dependencies

echo -e "${BOLD_CYAN}--- Preflight Checks & Credential Caching ---${NC}"

# Cache sudo credentials if privileged Linux (Cloudtop/GCP)
if is_privileged && is_linux; then
    echo "This script requires superuser privileges for some package installations."
    echo "Please enter your password if prompted:"
    sudo -v || exit 1
    # Keep-alive: update existing sudo time stamp until script exits
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
fi

# Cache SSH/SSO credentials by triggering a dummy remote check in the foreground.
# This ensures that any 1Password, Gnubby, or SSH passphrase prompts happen NOW.
if command -v git >/dev/null 2>&1; then
    echo "Touching GitHub to cache SSH credentials..."
    git ls-remote git@github.com:GoogleCloudPlatform/cluster-toolkit.git >/dev/null 2>&1

    if is_work && is_privileged; then
        echo "Touching Gerrit to cache SSO credentials..."
        git ls-remote sso://cloudhpc/sup-ssh-utils >/dev/null 2>&1
    fi
fi

echo -e "${BOLD_GREEN}Preflight complete. All credentials cached.${NC}\n"
