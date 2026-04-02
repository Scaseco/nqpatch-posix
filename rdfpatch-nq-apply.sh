#!/bin/bash
set -euo pipefail

# Standardize collation globally to prevent "not sorted" errors
export LC_ALL=C

if [ $# -lt 2 ]; then
  echo "Usage: $0 base.nq patch1.rdfp [patch2.rdfp ...]" >&2
  echo
  echo "Apply sorted .rdfp patches (A/D prefix + sorted payload) to sorted .nq"
  echo
  echo "💡 Pro-Tip: Use process substitution for compressed/encoded data:"
  echo "  $0 <(lbzcat base.nq.bz2) <(lbzcat patch.rdfp.bz2)"
  exit 1
fi

BASE_FILE="$1"
shift

# Function to apply a patch as a stream filter
apply_patch_filter() {
    local patch_file="$1"

    # TODO Remove? → We use --nocheck-order to stop comm from crashing on minor buffer/timing blips.
    # We assume the user has sorted their inputs correctly.
    comm -23 - <(sed -n 's/^D //p' "$patch_file") | \
    sort -m - <(sed -n 's/^A //p' "$patch_file")
}

# 1. Start the stream with the base file
# 2. Sequentially pipe through each patch filter
# This creates a single long pipeline: cat | filter | filter | ...
CMD="cat \"$BASE_FILE\""
for patch in "$@"; do
    # We append the filter logic to the command string
    # We use a subshell for the filter to keep logic encapsulated
    CMD="$CMD | apply_patch_filter \"$patch\""
done

# Execute the final pipeline
eval "$CMD"

