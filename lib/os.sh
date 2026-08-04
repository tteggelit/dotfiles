#!/usr/bin/env bash
# lib/os.sh - OS and environment detection

is_mac() {
    [ "$(uname -s)" = "Darwin" ]
}

is_linux() {
    [ "$(uname -s)" = "Linux" ]
}

is_work() {
    [ "${PROFILE}" = "work" ]
}

is_privileged() {
    [ "${PRIVILEGED}" = "yes" ]
}

is_slurm() {
    [ "${SLURM}" = "yes" ]
}

# Checks if running on authorized GCP Service Account
check_gcp_authorization() {
    [ -n "${IS_GCP_AUTHORIZED}" ] && return 0 # Already cached

    if ! command -v curl >/dev/null 2>&1; then
        export IS_GCP_AUTHORIZED=false
        return 1
    fi

    local current_sa
    current_sa=$(curl -s --connect-timeout 2 -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email 2>/dev/null)

    if [ -z "$current_sa" ]; then
        export IS_GCP_AUTHORIZED=false
        return 1
    fi

    local current_sa_hash
    if command -v sha256sum >/dev/null 2>&1; then
        current_sa_hash=$(echo -n "${current_sa}" | sha256sum | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        current_sa_hash=$(echo -n "${current_sa}" | shasum -a 256 | awk '{print $1}')
    else
        export IS_GCP_AUTHORIZED=false
        return 1
    fi

    export IS_GCP_AUTHORIZED=false
    # ALLOWED_GCP_SA_HASHES is expected to be defined in setup.sh
    for hash in "${ALLOWED_GCP_SA_HASHES[@]}"; do
        if [ "${current_sa_hash}" = "${hash}" ]; then
            export IS_GCP_AUTHORIZED=true
            break
        fi
    done
}

is_gcp_authorized() {
    check_gcp_authorization
    [ "${IS_GCP_AUTHORIZED}" = "true" ]
}
