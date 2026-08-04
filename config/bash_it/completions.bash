#!/usr/bin/env bash
# config/bash_it/completions.bash - Custom autocompletions

# Cluster Toolkit (ghpc)
if command -v ghpc >/dev/null 2>&1; then
    eval "$(ghpc completion bash)"
fi
