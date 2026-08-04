#!/usr/bin/env bash
# lib/utils.sh - Idempotent helper functions

# Safely symlink a file, backing up any existing file
symlink_file() {
    local src="$1"
    local dest="$2"

    # If already linked correctly, do nothing
    if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
        return 0
    fi

    # If exists (file, dir, or broken/wrong link), back it up
    if [ -e "$dest" ] || [ -L "$dest" ]; then
        mv "$dest" "${dest}.bak"
    fi

    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

# Clone or pull a git repository idempotently
git_clone_or_pull() {
    local url="$1"
    local dest="$2"
    local branch="${3:-}"
    local depth="${4:-}"
    shift 4 || true
    local extra_opts=("$@")

    local clone_opts=()
    [ -n "$branch" ] && clone_opts+=(--branch "$branch")
    [ -n "$depth" ] && clone_opts+=(--depth "$depth")
    clone_opts+=("${extra_opts[@]}")

    if [ ! -d "$dest" ]; then
        mkdir -p "$(dirname "$dest")"
        git clone "${clone_opts[@]}" "$url" "$dest"
    else
        pushd "$dest" >/dev/null
        # Fetch first to ensure we have all refs/tags
        git fetch --all --tags --quiet

        if [ -n "$branch" ]; then
            git checkout "$branch" >/dev/null 2>&1
        fi

        # Only pull if we are on a tracking branch (not detached HEAD/tag)
        if git symbolic-ref -q HEAD >/dev/null; then
            git pull --quiet
        fi
        popd >/dev/null
    fi
}

# Clone/Pull a Gerrit repo and ensure the commit hook is installed
setup_gerrit_repo() {
    local url="$1"
    local dest="$2"
    local branch="${3:-}"
    local depth="${4:-}"

    git_clone_or_pull "$url" "$dest" "$branch" "$depth" || return 1

    local hook="${dest}/.git/hooks/commit-msg"
    if [ ! -x "$hook" ]; then
        mkdir -p "$(dirname "$hook")"
        curl -s -Lo "$hook" https://gerrit-review.googlesource.com/tools/hooks/commit-msg
        chmod +x "$hook"
    fi
}

# Clone/Pull a GitHub fork and configure the upstream remote
setup_github_fork() {
    local url="$1"
    local dest="$2"
    local upstream="$3"
    local branch="${4:-}"
    local depth="${5:-}"

    git_clone_or_pull "$url" "$dest" "$branch" "$depth" || return 1

    pushd "$dest" >/dev/null
    if ! git remote | grep -q "^upstream$"; then
        git remote add upstream "$upstream"
    else
        git remote set-url upstream "$upstream"
    fi
    git fetch upstream --quiet
    popd >/dev/null
}
