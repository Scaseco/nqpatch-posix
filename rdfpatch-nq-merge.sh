#!/bin/bash
set -euo pipefail
export LC_ALL=C

# Resolve an argument to a command string factory
# Use zcat -f as a universal source (works for .bz2 if zutils is installed)
resolve_factory() {
    [[ "$1" == @* ]] && echo "${1:1}" || echo "zcat -f -- \"$1\""
}

if [ $# -lt 1 ]; then
    echo "Usage: $0 patch1.rdfp [patch2.rdfp ...]" >&2
    exit 1
fi

# Build the command to merge the pre-sorted streams
# We use -k2 to ignore the A/D prefix during the merge comparison
# Sort must be stable (-s) because argument order is relevant!
MERGE_CMD="sort -m -k2 -s"
for arg in "$@"; do
    FACTORY=$(resolve_factory "$arg")
    MERGE_CMD="$MERGE_CMD <(eval \"$FACTORY\")"
done

# The State Machine:
# Since identical triples are now adjacent, we resolve their net effect.
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

