#!/bin/bash
set -euo pipefail

# nqpatch track create: Create tracking metadata for patches
# Usage: nqpatch track create old.nq new.nq [patch.rdfp]
#
# Creates:
#   old.sha1, new.sha1, patch.sha1 (hash files)
#   patch.rel (lineage file: from-sha1 to-sha1)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 old.nq new.nq [patch.rdfp]" >&2
    echo "" >&2
    echo "Create tracking metadata for a patch operation." >&2
    echo "If patch.rdfp is not provided, it will be generated automatically." >&2
    exit 1
fi

OLD_FILE="$1"
NEW_FILE="$2"
PATCH_FILE="${3:-}"

# Verify input files exist
if [ ! -f "$OLD_FILE" ]; then
    echo "Error: old file not found: $OLD_FILE" >&2
    exit 1
fi

if [ ! -f "$NEW_FILE" ]; then
    echo "Error: new file not found: $NEW_FILE" >&2
    exit 1
fi

# Create SHA1 hash files
create_sha1_file() {
    local file="$1"
    local sha1_file="${file}.sha1"
    
    if [ ! -f "$sha1_file" ]; then
        sha1sum "$file" | awk '{print $1}' > "$sha1_file"
    fi
}

create_sha1_file "$OLD_FILE"
create_sha1_file "$NEW_FILE"

# Generate or verify patch file
if [ -n "$PATCH_FILE" ]; then
    if [ ! -f "$PATCH_FILE" ]; then
        echo "Error: patch file not found: $PATCH_FILE" >&2
        exit 1
    else
        # Verify patch is valid by checking it can be processed
        # (just check it has A/D prefixes)
        if ! head -n1 "$PATCH_FILE" | grep -qE '^[AD] '; then
            echo "Error: invalid patch format (must start with A or D): $PATCH_FILE" >&2
            exit 1
        fi
    fi
else
    # Generate patch automatically in the same directory as input files
    # Use a unique name based on input file basenames
    OLD_BASE=$(basename "$OLD_FILE" .nq)
    NEW_BASE=$(basename "$NEW_FILE" .nq)
    PATCH_DIR=$(dirname "$OLD_FILE")
    PATCH_FILE="$PATCH_DIR/patch-${OLD_BASE}-to-${NEW_BASE}.rdfp"
    "$SCRIPT_DIR/nqpatch-create.sh" "$OLD_FILE" "$NEW_FILE" > "$PATCH_FILE"
    # Note: temp patch file will remain; caller should clean up if needed
fi

# Create patch.sha1
PATCH_SHA1_FILE="${PATCH_FILE}.sha1"
if [ ! -f "$PATCH_SHA1_FILE" ]; then
    sha1sum "$PATCH_FILE" | awk '{print $1}' > "$PATCH_SHA1_FILE"
else
    # Verify existing patch.sha1 matches current patch
    EXPECTED_SHA1=$(cat "$PATCH_SHA1_FILE")
    ACTUAL_SHA1=$(sha1sum "$PATCH_FILE" | awk '{print $1}')
    if [ "$EXPECTED_SHA1" != "$ACTUAL_SHA1" ]; then
        echo "Error: patch.sha1 does not match patch file. Expected: $EXPECTED_SHA1, Got: $ACTUAL_SHA1" >&2
        exit 1
    fi
fi

# Create patch.rel
PATCH_REL_FILE="${PATCH_FILE}.rel"
OLD_SHA1=$(cat "${OLD_FILE}.sha1")
NEW_SHA1=$(cat "${NEW_FILE}.sha1")

echo "$OLD_SHA1 $NEW_SHA1" > "$PATCH_REL_FILE"

echo "Created tracking metadata:"
echo "  ${OLD_FILE}.sha1    ($OLD_SHA1)"
echo "  ${NEW_FILE}.sha1    ($NEW_SHA1)"
echo "  ${PATCH_FILE}.sha1  ($(cat $PATCH_SHA1_FILE))"
echo "  ${PATCH_FILE}.rel   ($OLD_SHA1 -> $NEW_SHA1)"
