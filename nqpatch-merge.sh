#!/bin/bash
set -euo pipefail

# Export to any factory expressions!
export LC_ALL=C

if [ $# -lt 1 ]; then
    echo "Usage: $0 patch1.rdfp [patch2.rdfp ...]" >&2
    exit 1
fi

# Resolves a file argument to a command string that streams its decoded content
stream_cmd() { printf 'zcat -f -- %q' "$1"; }

# Calculate a safe batch size based on system limits
# Without this fiddling, sort -m will block if given more than 16 arguments.
MAX_FDS=$(ulimit -n)
SAFE_BATCH=$(( MAX_FDS - 20 )) # Leave room for script overhead

MERGE_CMD="sort -m -s -k2 --batch-size=$SAFE_BATCH"
for arg in "$@"; do
    PATCH_STREAM_CMD=$(stream_cmd "$arg")
    MERGE_CMD="$MERGE_CMD <($PATCH_STREAM_CMD)"
done

# The State Machine: Identical quads are now adjacent and
# corresponding A/D flags appear in argument order due to stable sort.
# We resolve their net effect.
eval "$MERGE_CMD" | awk '
    function emit() {
        if (state == "A") print "A " last_quad
        else if (state == "D") print "D " last_quad
    }

    {
        op = $1
        if (op != "A" && op != "D" && op != "") {
            print "ERROR: line " NR ": [" $0 "]" > "/dev/stderr"
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

