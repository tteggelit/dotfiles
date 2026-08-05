#!/usr/bin/env bash
# tasks/04-packages.sh - Python packages and Pandoc

# Setup Python paths in the foreground so exports are reliable
PYUSERBASE=$(python3 -c "import site; print(site.USER_BASE)" 2>/dev/null)
PYLOCAL="${HOME}/.local"
export PYUSERBASE PYLOCAL

setup_pylocal_dirs() {
    if [ ! -e "${PYLOCAL}" ]; then
        if is_mac; then
            [ ! -d "${PYUSERBASE}" ] && install -d "${PYUSERBASE}"
            ln -sf "${PYUSERBASE}" "${PYLOCAL}"
        else
            install -d "${PYLOCAL}"
            install -d "${PYLOCAL}/bin"
            install -d "${PYLOCAL}/share"
        fi
    fi
    install -d "${PYLOCAL}/tmp"
}
run_task "Configure local Python directories" setup_pylocal_dirs

# Determine PIP Options in foreground to export to other modules
PIP_VERSION=$(python3 -m pip --version 2>/dev/null | awk '{print $2}')
PIP_MAJOR=$(echo "${PIP_VERSION}" | cut -d. -f1)
PIP_MINOR=$(echo "${PIP_VERSION}" | cut -d. -f2)

PIP_OPTIONS="--user"
if (( PIP_MAJOR >= 23 && PIP_MINOR >= 1 )); then
   PIP_OPTIONS="--user --break-system-packages"
elif is_work && is_privileged; then
   PIP_OPTIONS="--user --break-system-packages"
fi
export PIP_OPTIONS

# Install flake8
if ! command -v flake8 >/dev/null 2>&1; then
    if is_mac; then
        run_task "Install flake8 via Homebrew" brew install flake8
    else
        run_task "Install flake8 via pip" python3 -m pip install ${PIP_OPTIONS} flake8
    fi
fi

# Install Pygments
if ! command -v pygmentize >/dev/null 2>&1; then
    if is_mac; then
        run_task "Install Pygments via Homebrew" brew install pygments
    else
        run_task "Install Pygments via pip" python3 -m pip install ${PIP_OPTIONS} Pygments
    fi
fi

# Install Pandoc
if ! command -v pandoc >/dev/null 2>&1; then
    if is_mac; then
        run_task "Install Pandoc via Homebrew" brew install groff pandoc
    else
        install_linux_pandoc() {
            local PANDOC_ARCH="unknown"
            case "$(uname -m)" in
                "x86_64") PANDOC_ARCH="amd64" ;;
                "aarch64") PANDOC_ARCH="arm64" ;;
            esac

            if [ "$PANDOC_ARCH" = "unknown" ]; then
                echo "There isn't a prebuilt pandoc binary for this architecture."
                return 1
            fi

            local PANDOC_VER="3.1.8"
            local tarball="pandoc-${PANDOC_VER}-linux-${PANDOC_ARCH}.tar.gz"
            local tmp_dir="${PYLOCAL}/tmp"

            pushd "$tmp_dir" >/dev/null
            [ -f "$tarball" ] && rm -f "$tarball"
            curl -s -S -L -O -f "https://github.com/jgm/pandoc/releases/download/${PANDOC_VER}/${tarball}" || return 1
            tar zxf "$tarball" -C "${PYLOCAL}" || return 1
            rm -f "$tarball"
            popd >/dev/null

            local p_dir="${PYLOCAL}/pandoc"
            local p_ver_dir="${PYLOCAL}/pandoc-${PANDOC_VER}"

            if [ -L "$p_dir" ]; then
                unlink "$p_dir"
                ln -sf "$p_ver_dir" "$p_dir"
            elif [ -d "$p_dir" ]; then
                echo "!!!!! $p_dir exists. Moving out of the way. !!!!!"
                mv "$p_dir" "${p_dir}.old"
                ln -sf "$p_ver_dir" "$p_dir"
            elif [ -e "$p_dir" ]; then
                echo "!!!!! $p_dir exists. Unsure what to do. !!!!!"
                return 1
            else
                ln -sf "$p_ver_dir" "$p_dir"
            fi

            [ ! -L "${PYLOCAL}/bin/pandoc" ] && ln -sf "${p_dir}/bin/pandoc" "${PYLOCAL}/bin/pandoc"
            # Fix: avoid obsolescent -o, just ensure leaf directory exists
            [ ! -d "${PYLOCAL}/share/man/man1" ] && install -d "${PYLOCAL}/share/man/man1"
            [ ! -L "${PYLOCAL}/share/man/man1/pandoc.1.gz" ] && ln -sf "${p_dir}/share/man/man1/pandoc.1.gz" "${PYLOCAL}/share/man/man1/pandoc.1.gz"

            return 0
        }
        run_task "Install Pandoc binary (Linux)" install_linux_pandoc
    fi
fi
