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

# Cluster Toolkit (Hybrid Binary/Source)
local CLUSTER_TOOLKIT_DIR="${GIT_DIR}/cluster-toolkit"

local BUNDLE_OS=""
local BUNDLE_ARCH=""
is_mac && BUNDLE_OS="darwin"
is_linux && BUNDLE_OS="linux"

case "$(uname -m)" in
    x86_64) BUNDLE_ARCH="amd64" ;;
    aarch64|arm64) BUNDLE_ARCH="arm64" ;;
esac

local use_binary=false
local bundle_name=""
if [ -n "$BUNDLE_OS" ] && [ -n "$BUNDLE_ARCH" ]; then
    use_binary=true
    bundle_name="gcluster_bundle_${BUNDLE_OS}_${BUNDLE_ARCH}.tgz"
fi

if [ "$use_binary" = true ]; then
    download_cluster_toolkit() {
        local tmp_dir="${PYLOCAL:-${HOME}/.local}/tmp"
        mkdir -p "$tmp_dir"

        local version
        version=$(git ls-remote --tags --refs --sort='version:refname' https://github.com/GoogleCloudPlatform/cluster-toolkit.git 2>/dev/null | tail -n 1 | cut -f2 | cut -d/ -f3)

        if [ -z "$version" ]; then
            version="v1.98.0" # Fallback if git fails
        fi

        local url="https://github.com/GoogleCloudPlatform/cluster-toolkit/releases/download/${version}/${bundle_name}"

        pushd "$tmp_dir" >/dev/null
        [ -f "$bundle_name" ] && rm -f "$bundle_name"
        curl -s -S -L -O "$url" || return 1

        rm -rf "$CLUSTER_TOOLKIT_DIR"
        mkdir -p "$CLUSTER_TOOLKIT_DIR"
        tar zxf "$bundle_name" -C "$CLUSTER_TOOLKIT_DIR" || return 1
        rm -f "$bundle_name"
        popd >/dev/null

        chmod +x "${CLUSTER_TOOLKIT_DIR}/gcluster"
        return 0
    }
    run_task "Download pre-compiled Cluster Toolkit bundle (${BUNDLE_OS}/${BUNDLE_ARCH})" download_cluster_toolkit
else
    run_task "Setup Cluster Toolkit (Source)" git_clone_or_pull "git@github.com:GoogleCloudPlatform/cluster-toolkit.git" "$CLUSTER_TOOLKIT_DIR"

    if [ -d "$CLUSTER_TOOLKIT_DIR" ]; then
        build_cluster_toolkit() {
            if ! command -v go >/dev/null 2>&1 || ! command -v terraform >/dev/null 2>&1; then
                echo "Warning: Build requirements (Go, Terraform) are missing. Skipping Cluster Toolkit build."
                return 0
            fi

            pushd "$CLUSTER_TOOLKIT_DIR" >/dev/null
            make || return 1
            popd >/dev/null
            return 0
        }
        run_task "Build Cluster Toolkit" build_cluster_toolkit
    fi
fi

if [ -d "$CLUSTER_TOOLKIT_DIR" ]; then
    export PATH="${PATH}:${CLUSTER_TOOLKIT_DIR}"
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
