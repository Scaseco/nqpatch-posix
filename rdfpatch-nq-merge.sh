#!/bin/bash
set -euo pipefail

# Export to any factory expressions!
export LC_ALL=C

if [ $# -lt 1 ]; then
    echo "Usage: $0 patch1.rdfp [patch2.rdfp ...]" >&2
    exit 1
fi

# Resolves an argument to a command string factory
# Arguments starting with '@' are interpreted as commands, such as '@lbzcat patch1.rdfp.bz2'.
# Uses zcat -f as a universal source (works for several formats including .bz2 if zutils is installed)
resolve_factory() {
    [[ "$1" == @* ]] && echo "${1:1}" || printf 'zcat -f -- %q' "$1"
}

# Calculate a safe batch size based on system limits
# Without this fiddling, sort -m will block if given more than 16 arguments.
MAX_FDS=$(ulimit -n)
SAFE_BATCH=$(( MAX_FDS - 20 )) # Leave room for script overhead

# Build the command to merge the pre-sorted streams
# We use -k2 to ignore the A/D prefix during the merge comparison
# Sort must be stable (-s) because argument order is relevant!
MERGE_CMD="sort -m -s -k2 --batch-size=$SAFE_BATCH"
for arg in "$@"; do
    FACTORY=$(resolve_factory "$arg")
    MERGE_CMD="$MERGE_CMD <($FACTORY)"
done

# The State Machine: Identical quads are now adjacent and
# corresponding A/D flags appear in argument order due to stable sort.
# We resolve their net effect.
eval "$MERGE_CMD" | awk '
    function emit() {
        if (state == "A") print "A " last_triple
        if (state == "D") print "D " last_triple
    }

    {
        op = $1
        # Extract everything after "A " or "D "
        triple = substr($0, 3)

        if (triple != last_triple) {
            emit()
            state = op
            last_triple = triple
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

