#!/bin/bash
set -euo pipefail
export LC_ALL=C

# Helper: Detects file type and returns the proper 'cat' command
get_cat_cmd() {
    local file="$1"
    if [[ "$file" == *.bz2 ]]; then
        echo "lbzcat \"$file\""
    elif [[ "$file" == *.gz ]]; then
        echo "zcat \"$file\""
    else
        echo "cat \"$file\""
    fi
}

# The core logic: resolves an argument to a "factory" command string
resolve_factory() {
    local arg="$1"
    if [[ "$arg" == @* ]]; then
        # It's a factory command (remove the leading @)
        echo "${arg:1}"
    else
        # It's a regular file; auto-detect the cat tool
        get_cat_cmd "$arg"
    fi
}

apply_one_patch() {
    local base_cmd="$1"
    local patch_factory="$2"

    # Evaluate the patch factory twice to avoid stream deadlocks
    comm -23 \
        <(eval "$base_cmd") \
        <(eval "$patch_factory" | sed -n 's/^D //p') \

    | sort -m - \
        <(eval "$patch_factory" | sed -n 's/^A //p')
}

# Main initialization
CURRENT=$(resolve_factory "$1")

for arg in "${@:2}"; do
    FACTORY=$(resolve_factory "$arg")
    CURRENT="apply_one_patch \"$CURRENT\" \"$FACTORY\""
done

eval "$CURRENT"

