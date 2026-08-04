#!/usr/bin/env bash
# setup.sh - Main orchestrator for dotfiles setup

# 1. Enforce Bash and Git prerequisites
if [ -z "$BASH_VERSION" ]; then
    echo "Error: This script requires Bash. Please run it as: bash setup.sh" >&2
    exit 1
fi
if ! command -v git >/dev/null 2>&1; then
    echo "Error: git is not installed. Please install git before running this script." >&2
    exit 1
fi

# 2. Global Configurations
HOME_EMAIL="ti@daleggetts.com"
HOME_SSHKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHMOKogNrOncCCAKczMINsi5rKoOOEEqLB+9bcNpzuDf"
WORK_EMAIL="tileggett@google.com"
WORK_SSHKEY="key::ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBPBZJcRJEqcyZ6AvB18FkqcRldx6rK4Ty2G73rbntrficMf9UKWPSaBDupmW6tauRE3lpmlvJHGowg0L09xehwY= tileggett@gnubby.key"

SPACK_VERSION="1.2.2"

ALLOWED_GCP_SA_HASHES=(
    "74c2432577bbc644b93f21e9b502ee9795a248a69b6e3f97b3468ad2209b9c86"
)

PROFILE="home"
EMAIL="${HOME_EMAIL}"
SSHKEY="${HOME_SSHKEY}"

SLURM="no"
PRIVILEGED="no"

# 3. Parse Options
while getopts "psw" opt; do
    case ${opt} in
        w)
            PROFILE="work"
            EMAIL="${WORK_EMAIL}"
            SSHKEY="${WORK_SSHKEY}"
            ;;
        s)
            SLURM="yes"
            ;;
        p)
            PRIVILEGED="yes"
            ;;
        *)
            echo "Usage: $0 [-p] [-s] [-w]" >&2
            exit 1
            ;;
    esac
done

# 4. Environment and Libraries
export DOTFILES_DIR
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
for lib in colors.sh logging.sh os.sh utils.sh; do
    source "${DOTFILES_DIR}/lib/${lib}" || { echo "Failed to load ${lib}"; exit 1; }
done

# Export variables so tasks and background subshells can read them
export PROFILE EMAIL SSHKEY SLURM PRIVILEGED SPACK_VERSION ALLOWED_GCP_SA_HASHES

# Initialize log file
init_log

echo -e "${BOLD_PURPLE}=================================================="
echo -e "Starting Dotfiles Setup"
echo -e "Profile:     ${PROFILE}"
echo -e "Privileged:  ${PRIVILEGED}"
echo -e "Slurm:       ${SLURM}"
echo -e "Log File:    ${LOG_FILE}"
echo -e "==================================================${NC}\n"

# Trap Ctrl-C to clean up gracefully
cleanup() {
    echo -e "\n${BOLD_RED}Setup interrupted. Exiting.${NC}"
    exit 1
}
trap cleanup SIGINT SIGTERM

# 5. Run Tasks
for task in "${DOTFILES_DIR}/tasks/"*.sh; do
    [ -f "$task" ] || continue

    task_name=$(basename "$task")
    echo -e "${BOLD_WHITE}>>> Running task: ${task_name}${NC}"
    source "$task"
    echo ""
done

# 6. Cleanup and Summary
[ -n "${PYLOCAL}" ] && [ -d "${PYLOCAL}/tmp" ] && rm -rf "${PYLOCAL}/tmp"

echo -e "${BOLD_GREEN}=================================================="
echo -e "Setup completed successfully!"
echo -e "Detailed logs are available at: ${LOG_FILE}"
echo -e "Please restart your shell or run: source ~/.bash_profile"
echo -e "==================================================${NC}"
