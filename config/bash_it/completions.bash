#!/usr/bin/env bash
# config/bash_it/completions.bash - Custom autocompletions

# Cluster Toolkit (gcluster / ghpc)
if command -v gcluster >/dev/null 2>&1; then
    eval "$(gcluster completion bash)"
elif command -v ghpc >/dev/null 2>&1; then
    eval "$(ghpc completion bash)"
fi
