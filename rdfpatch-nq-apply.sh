#!/bin/bash
set -euo pipefail
export LC_ALL=C

# Resolve an argument to a command string factory
# Use zcat -f as a universal source (works for .bz2 if zutils is installed)
resolve_factory() {
    [[ "$1" == @* ]] && echo "${1:1}" || echo "zcat -f -- \"$1\""
}

apply_one_patch() {
    local base_cmd="$1"
    local patch_factory="$2"

    # We evaluate the patch factory twice to avoid the comm/sort deadlock.
    # This allows comm and sort to pull data independently.
    comm -23 \
        <(eval "$base_cmd") \
        <(eval "$patch_factory" | sed -n 's/^D //p') \
    | sort -m - \
        <(eval "$patch_factory" | sed -n 's/^A //p')
}

if [ $# -lt 1 ]; then
    echo "Usage: $0 base.nt[.bz2] [patch1.rdfp[.bz2] ...]" >&2
    exit 1
fi

# Initialize the pipeline with the base file
CURRENT=$(resolve_factory "$1")

# Sequentially wrap the command for each patch
for arg in "${@:2}"; do
    FACTORY=$(resolve_factory "$arg")
    # Use printf %q to properly escape arguments for eval
    CURRENT=$(printf 'apply_one_patch %s %s' "$(printf '%q' "$CURRENT")" "$(printf '%q' "$FACTORY")")
done

# Execute the final nested command
eval "$CURRENT"

