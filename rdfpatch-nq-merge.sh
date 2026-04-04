#!/bin/bash
set -euo pipefail

# Export to any factory expressions!
export LC_ALL=C

if [ $# -lt 1 ]; then
    echo "Usage: $0 patch1.rdfp [patch2.rdfp ...]" >&2
    exit 1
fi

# Calculate a safe batch size based on system limits
MAX_FDS=$(ulimit -n)
SAFE_BATCH=$(( MAX_FDS - 20 )) # Leave room for script overhead

# Resolves an argument to a command string factory
# Arguments starting with '@' are interpreted as commands
# Uses zcat -f as a universal source (works for .bz2 if zutils is installed)
resolve_factory() {
    [[ "$1" == @* ]] && echo "${1:1}" || printf 'zcat -f -- %q\n' "$1"
}

fds=()
for arg in "$@"; do
    FACTORY=$(resolve_factory "$arg")
    # Open FD and store path
    if exec {fd}< <(eval "$FACTORY"); then
        fds+=( "/dev/fd/$fd" )
        OPEN_FDS+=( "$fd" )
    else
        echo "Failed to open stream for $arg" >&2
        exit 1
    fi
done

# Run sort with the dynamic batch size
sort -m --batch-size="$SAFE_BATCH" -k2 -s "${fds[@]}" | awk '
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

