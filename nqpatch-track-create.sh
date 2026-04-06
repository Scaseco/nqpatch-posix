#!/bin/bash
set -euo pipefail

# nqpatch track create: Create tracking metadata for patches
# Usage: nqpatch track create old.nq new.nq [patch.rdfp[.gz|.bz2]]
#
# Creates:
#   old.sha1, new.sha1, patch.sha1 (hash files)
#   patch.rel (lineage file: from-sha1 to-sha1)
#
# Patch output compression is auto-detected from file extension:
#   .gz  -> gzip
#   .bz2 -> bzip2
#   .xz  -> xz
#   .zst -> zstd
#   (none) -> plain text

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Detect compression tool from file extension
detect_compressor() {
    local file="$1"
    case "$file" in
        *.gz)  echo "gzip" ;;
        *.bz2) echo "bzip2" ;;
        *.xz)  echo "xz" ;;
        *.zst) echo "zstd" ;;
        *)     echo "cat" ;;
    esac
}

# Detect decompressor from file extension (for reading)
detect_decompressor() {
    local file="$1"
    case "$file" in
        *.gz|*.bz2|*.xz|*.zst) echo "zcat" ;;
        *)                     echo "cat" ;;
    esac
}

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 old.nq new.nq [patch.rdfp[.gz|.bz2]]" >&2
    echo "" >&2
    echo "Create tracking metadata for a patch operation." >&2
    echo "If patch is not provided, it will be generated automatically." >&2
    echo "Compression is auto-detected from patch filename extension." >&2
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
        DECOMPRESSOR=$(detect_decompressor "$PATCH_FILE")
        if ! $DECOMPRESSOR "$PATCH_FILE" 2>/dev/null | head -n1 | grep -qE '^[AD] '; then
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
    # Preserve compression extension from inputs if present
    OLD_EXT=""
    case "$OLD_FILE" in
        *.gz)  OLD_EXT=".gz" ;;
        *.bz2) OLD_EXT=".bz2" ;;
        *.xz)  OLD_EXT=".xz" ;;
        *.zst) OLD_EXT=".zst" ;;
    esac
    NEW_EXT=""
    case "$NEW_FILE" in
        *.gz)  NEW_EXT=".gz" ;;
        *.bz2) NEW_EXT=".bz2" ;;
        *.xz)  NEW_EXT=".xz" ;;
        *.zst) NEW_EXT=".zst" ;;
    esac
    # If both have same extension, use it; otherwise use plain
    if [ "$OLD_EXT" = "$NEW_EXT" ] && [ -n "$OLD_EXT" ]; then
        PATCH_EXT="$OLD_EXT"
    else
        PATCH_EXT=""
    fi
    PATCH_FILE="$PATCH_DIR/patch-${OLD_BASE}-to-${NEW_BASE}.rdfp${PATCH_EXT}"
    COMPRESSOR=$(detect_compressor "$PATCH_FILE")
    "$SCRIPT_DIR/nqpatch-create.sh" "$OLD_FILE" "$NEW_FILE" | $COMPRESSOR > "$PATCH_FILE"
    # Note: patch file will remain; caller should clean up if needed
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
