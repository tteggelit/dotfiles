#!/usr/bin/env bash
# lib/logging.sh - Noise reduction, spinners, and interactive error handling

[ -z "${DOTFILES_DIR}" ] && export DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${DOTFILES_DIR}/lib/colors.sh"

LOG_FILE="${DOTFILES_DIR}/setup.log"

init_log() {
    echo "=== Setup Log Started $(date) ===" > "$LOG_FILE"
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    printf "  " >&2
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\b\b%c " "$spinstr" >&2
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\b\b  \b\b" >&2
}

run_task() {
    local msg="$1"
    shift
    local cmd="$*"

    if [ -t 1 ]; then
        printf "${BOLD_BLUE}[ RUNNING ]${NC} %s... " "$msg"
    else
        printf "[ RUNNING ] %s...\n" "$msg"
    fi

    echo "=== $(date) : Executing '$cmd' ===" >> "$LOG_FILE"

    # Run in background to allow spinner if TTY
    eval "$cmd" >> "$LOG_FILE" 2>&1 &
    local pid=$!

    if [ -t 1 ]; then
        spinner "$pid"
    fi

    wait "$pid"
    local rc=$?

    if [ $rc -eq 0 ]; then
        if [ -t 1 ]; then
            printf "\r${BOLD_GREEN}[   OK   ]${NC} %s    \n" "$msg"
        else
            printf "[   OK   ] %s\n" "$msg"
        fi
        return 0
    else
        if [ -t 1 ]; then
            printf "\r${BOLD_RED}[ FAILED ]${NC} %s    \n" "$msg"
        else
            printf "[ FAILED ] %s\n" "$msg"
        fi
        handle_error "$msg" "$cmd" "$rc"
        return $?
    fi
}

handle_error() {
    local msg="$1"
    local cmd="$2"
    local rc="$3"

    echo -e "\n${BOLD_RED}=================================================="
    echo -e "TASK FAILED: ${msg}"
    echo -e "Command:     ${cmd}"
    echo -e "Exit Code:   ${rc}"
    echo -e "==================================================${NC}\n"

    echo -e "${YELLOW}Last 10 lines of ${LOG_FILE}:${NC}"
    tail -n 10 "$LOG_FILE"
    echo -e "${YELLOW}--------------------------------------------------${NC}\n"

    if [ ! -t 1 ]; then
        echo "Non-interactive environment detected. Aborting."
        exit "$rc"
    fi

    while true; do
        read -p "Choose an action: [A]bort, [R]etry, [I]gnore? " yn < /dev/tty
        case $yn in
            [Aa]* )
                echo -e "${RED}Aborting setup.${NC}"
                exit "$rc"
                ;;
            [Rr]* )
                echo -e "${BLUE}Retrying task...${NC}"
                run_task "$msg" "$cmd"
                return $?
                ;;
            [Ii]* )
                echo -e "${YELLOW}Ignoring failure and continuing.${NC}"
                return 0
                ;;
            * )
                echo "Please answer A, R, or I."
                ;;
        esac
    done
}
