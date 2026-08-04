#!/usr/bin/env bash
# config/bash_it/aliases.bash - Custom aliases and functions

# --- Slurm Enhancements ---
if command -v squeue >/dev/null 2>&1; then
    alias sq="squeue -o '%.10i %.9P %.15j %.10u %.2t %.10M %.6D %R'"
fi
if command -v sinfo >/dev/null 2>&1; then
    alias si="sinfo -o '%.10P %.5a %.10l %.16F'"
fi

# --- GCloud Shortcuts ---
if command -v gcloud >/dev/null 2>&1; then
    alias gci="gcloud compute instances list"
    alias gcssh="gcloud compute ssh"
fi

# --- Cluster Toolkit (gcluster / ghpc) ---
if command -v gcluster >/dev/null 2>&1; then
    alias gcd="gcluster deploy"
    alias gcx="gcluster destroy"
elif command -v ghpc >/dev/null 2>&1; then
    alias gcd="ghpc deploy"
    alias gcx="ghpc destroy"
fi

# --- Work / Google specific ---
[ -f /google/bin/releases/jetski-devs/tools/cli ] && alias jetski="/google/bin/releases/jetski-devs/tools/cli"
[ -f /google/bin/releases/gemini-cli/tools/gemini ] && alias gemini="/google/bin/releases/gemini-cli/tools/gemini"

# --- Ramble Shortcuts ---
if [ -d "${HOME}/git/ramble" ]; then
    alias prw='pushd "${RAMBLE_WORKSPACE:-${HOME}/git/ramble}"'
    alias ro="ramble on"
    alias rwa="ramble workspace activate"
    alias rwan="ramble workspace analyze"
    alias rwc="ramble workspace create"
    alias rwd="ramble workspace deactivate"
    alias rwe="ramble workspace edit"
    alias rwi="ramble workspace info"
    alias rwls="ramble workspace list"
    alias rwrm="ramble workspace remove"
    alias rws="ramble workspace setup"
fi
