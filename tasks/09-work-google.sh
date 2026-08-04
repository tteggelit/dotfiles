#!/usr/bin/env bash
# tasks/09-work-google.sh - Work Profile (Google) configurations

is_work || return 0

echo -e "${BOLD_CYAN}--- Work Profile Configurations ---${NC}"

# 1. Apt packages for privileged Linux
if is_linux && is_privileged; then
    run_task "Install Google CLI tools" sudo apt install -y git-remote-google google-cloud-cli
fi

# 2. Python venv
setup_venv() {
    if [ ! -d "${HOME}/.venv" ]; then
        python3 -m venv "${HOME}/.venv"
    fi
}
run_task "Create Python virtual environment" setup_venv

# Source in foreground so subsequent tasks in this module inherit the active venv
source "${HOME}/.venv/bin/activate"
run_task "Upgrade pip in venv" pip install --upgrade pip

# 3. Gerrit Repositories
GERRIT_DIR="${HOME}/gerrit"
mkdir -p "$GERRIT_DIR"

if is_privileged; then
    # Privileged uses SSO
    run_task "Setup sup-ssh-utils" setup_gerrit_repo "sso://cloudhpc/sup-ssh-utils" "${GERRIT_DIR}/sup-ssh-utils"

    if [ -d "${GERRIT_DIR}/sup-ssh-utils" ]; then
        # Add to PATH temporarily for the setup script to run
        export PATH="${GERRIT_DIR}/sup-ssh-utils:${PATH}"
        run_task "Run setup-gcp-ssh-host.bash" "pushd ${GERRIT_DIR}/sup-ssh-utils >/dev/null && ./setup-gcp-ssh-host.bash && popd >/dev/null"
    fi
else
    # Non-privileged (usually GCE) uses HTTP cookies
    run_task "Setup gcompute-tools" git_clone_or_pull "https://gerrit.googlesource.com/gcompute-tools" "${GERRIT_DIR}/gcompute-tools"

    # Configure git-cookie-authdaemon
    if [ -d "${GERRIT_DIR}/gcompute-tools" ]; then
        setup_git_cookie_daemon() {
            local systemd_user_path="${HOME}/.config/systemd/user"
            mkdir -p "$systemd_user_path"

            cat > "${systemd_user_path}/git-cookie-authdaemon.service" << EOF
[Unit]
Description=git-cookie-authdaemon required to access git-on-borg from GCE

Wants=network.target
After=syslog.target network-online.target

[Service]
Type=simple
ExecStart=${HOME}/.venv/bin/python3 ${GERRIT_DIR}/gcompute-tools/git-cookie-authdaemon
Restart=on-failure
RestartSec=10
KillMode=process

[Install]
WantedBy=multi-user.target
EOF

            # Start manually as in original script (TODO: debug systemd)
            # Fix: Bug #7 - Run with nohup to avoid blocking the setup script in case it doesn't fork cleanly
            if [ "$(pgrep --uid "$(id -u)" --full --count git-cookie-authdaemon)" -eq 0 ]; then
                nohup "${HOME}/.venv/bin/python3" "${GERRIT_DIR}/gcompute-tools/git-cookie-authdaemon" >/dev/null 2>&1 &
            fi

            [ "$(git config --global --get http.cookiefile)" != "${HOME}/.git-credential-cache/cookie" ] && git config --global http.cookiefile "${HOME}/.git-credential-cache/cookie"
            return 0
        }
        run_task "Configure Git Cookie Auth Daemon" setup_git_cookie_daemon
    fi
fi

# 4. Authorized GCP SA Repositories
# Fix: Bug #1 - Correctly uses our is_gcp_authorized helper which fixes the array typo
if is_gcp_authorized; then
    local gerrit_url="https://cloudhpc.googlesource.com"
    is_privileged && gerrit_url="sso://cloudhpc"

    run_task "Setup hpc-toolkit-blueprints" setup_gerrit_repo "${gerrit_url}/hpc-toolkit-blueprints" "${GERRIT_DIR}/hpc-toolkit-blueprints"
    run_task "Setup spack-packages (Gerrit)" setup_gerrit_repo "${gerrit_url}/spack-packages" "${GERRIT_DIR}/spack-packages"
    run_task "Setup ramble-applications" setup_gerrit_repo "${gerrit_url}/ramble-applications" "${GERRIT_DIR}/ramble-applications"
fi

# 5. GitHub Repositories
GIT_DIR="${HOME}/git"
mkdir -p "$GIT_DIR"

# Cluster Toolkit
run_task "Setup Cluster Toolkit" git_clone_or_pull "git@github.com:GoogleCloudPlatform/cluster-toolkit.git" "${GIT_DIR}/cluster-toolkit"
if [ -d "${GIT_DIR}/cluster-toolkit" ]; then
    run_task "Build Cluster Toolkit" "pushd ${GIT_DIR}/cluster-toolkit >/dev/null && make && popd >/dev/null"
    export PATH="${PATH}:${GIT_DIR}/cluster-toolkit"
fi

# Spack
run_task "Setup Spack" git_clone_or_pull "https://github.com/spack/spack.git" "${GIT_DIR}/spack" "tags/v${SPACK_VERSION}" "2"
if [ -f "${GIT_DIR}/spack/share/spack/setup-env.sh" ]; then
    source "${GIT_DIR}/spack/share/spack/setup-env.sh"
fi

# Spack-packages (GitHub Fork)
# Fix: Bug #5 - Using setup_github_fork safely adds upstream without failing if it exists
run_task "Setup Spack-packages Fork" setup_github_fork "git@github.com:tteggelit/spack-packages.git" "${GIT_DIR}/spack-packages" "https://github.com/spack/spack-packages.git" --depth=2

# Ramble
run_task "Setup Ramble" git_clone_or_pull "git@github.com:tteggelit/ramble.git" "${GIT_DIR}/ramble" "" "" -c feature.manyfiles=true
if [ -d "${GIT_DIR}/ramble" ]; then
    setup_github_fork "git@github.com:tteggelit/ramble.git" "${GIT_DIR}/ramble" "https://github.com/GoogleCloudPlatform/ramble.git"

    if [ -f "${GIT_DIR}/ramble/share/ramble/setup-env.sh" ]; then
        source "${GIT_DIR}/ramble/share/ramble/setup-env.sh"
    fi

    run_task "Install Ramble pip requirements" "pip install -r ${GIT_DIR}/ramble/requirements.txt"
    run_task "Install Ramble dev pip requirements" "pip install -r ${GIT_DIR}/ramble/requirements-dev.txt"

    if command -v pre-commit >/dev/null 2>&1 && [ ! -x "${GIT_DIR}/ramble/.git/hooks/pre-commit" ]; then
        run_task "Install Ramble pre-commit hooks" "pushd ${GIT_DIR}/ramble >/dev/null && pre-commit install && popd >/dev/null"
    fi
fi

# Add repos to spack/ramble
# Fix: Bug #4 - Removed the duplicate/broken line 511 outside this block. Only adds if authorized.
if is_gcp_authorized; then
    if command -v ramble >/dev/null 2>&1 && [ -d "${GERRIT_DIR}/ramble-applications" ]; then
        add_ramble_repo() {
            if ! ramble repo list | grep -q "${GERRIT_DIR}/ramble-applications"; then
                ramble repo add "${GERRIT_DIR}/ramble-applications"
            fi
        }
        run_task "Add Ramble applications repo" add_ramble_repo
    fi

    if command -v spack >/dev/null 2>&1 && [ -d "${GERRIT_DIR}/spack-packages" ]; then
        add_spack_repo() {
            if ! spack repo list | grep -q "${GERRIT_DIR}/spack-packages"; then
                spack repo add "${GERRIT_DIR}/spack-packages"
            fi
        }
        run_task "Add Spack packages repo" add_spack_repo
    fi
fi
