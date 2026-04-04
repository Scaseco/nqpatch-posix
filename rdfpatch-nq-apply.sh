#!/bin/bash
set -euo pipefail
export LC_ALL=C

if [ $# -lt 1 ]; then
    echo "Usage: $0 base.nt[.bz2] [patch1.rdfp[.bz2] ...]" >&2
    exit 1
fi

# Resolves an argument to a command string factory
# Arguments starting with '@' are interpreted as commands, such as '@lbzcat patch1.rdfp.bz2'.
# Uses zcat -f as a universal source (works for several formats including .bz2 if zutils is installed)
resolve_factory() {
    [[ "$1" == @* ]] && echo "${1:1}" || printf 'zcat -f -- %q' "$1"
}

BASE_FACTORY=$(resolve_factory "$1")
PATCHES=("${@:2}")

if [ "${#PATCHES[@]}" -eq 0 ]; then
    eval "$BASE_FACTORY"
    exit 0
fi

MAX_FDS=$(ulimit -n)
SAFE_BATCH=$(( MAX_FDS - 20 ))

# Build MERGE_CMD: include base as "A q", then patches
MERGE_CMD="sort -m -s -k2 --batch-size=$SAFE_BATCH"

# Base: wrap in <(...) and tag with "A "
MERGE_CMD="$MERGE_CMD <($BASE_FACTORY | sed 's/^/A /')"

# Patches: as-is (already "A q" or "D q")
for arg in "${PATCHES[@]}"; do
    FACTORY=$(resolve_factory "$arg")
    MERGE_CMD="$MERGE_CMD <($FACTORY)"
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

