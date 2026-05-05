#!/bin/bash
set -euo pipefail
export LC_ALL=C

if [ $# -lt 1 ]; then
    echo "Usage: $0 base.nt[.bz2] [patch1.rdfp[.bz2] ...]" >&2
    exit 1
fi

# Resolves a file argument to a command string that streams its decoded content
stream_cmd() { printf 'zcat -f -- %q' "$1"; }

MAX_FDS=$(ulimit -n)
SAFE_BATCH=$(( MAX_FDS - 20 ))

BASE_STREAM_CMD=$(stream_cmd "$1")
PATCHES=("${@:2}")

MERGE_CMD="sort -m -s -k2 --batch-size=$SAFE_BATCH" 

# Base: wrap in <(...) and tag with "A "
MERGE_CMD="$MERGE_CMD <($BASE_STREAM_CMD | sed 's/^/A /')"
 
# Patches: as-is (already "A q" or "D q")
for arg in "${PATCHES[@]}"; do
   PATCH_STREAM_CMD=$(stream_cmd "$arg")
   MERGE_CMD="$MERGE_CMD <($PATCH_STREAM_CMD)"
done

# Apply patches by treating base as adds, then reusing merge logic
eval "$MERGE_CMD" | awk '
    function emit() {
        if (state == "A") print last_quad
    }

    {
        op = $1
        if (op != "A" && op != "D" && op != "") {
            print "ERROR: line " NR ": " $0 > "/dev/stderr"
            exit 1
        }

        # Extract everything after "A " or "D "
        quad = substr($0, 3)
        if (quad != last_quad) {
            emit()
            state = op
            last_quad = quad
        } else {
            # Logic: If we have an existing state and a new op:
            # A + D = (nothing)
            # D + A = (nothing) 
            # A + A = A (duplicate add, shouldnt happen but handled)
            # D + D = D (duplicate delete)
            if (state == "A" && op == "D") state = ""
            else if (state == "D" && op == "A") state = ""
            else if (state == "") state = op
        }
    }
    END { emit() }
'

