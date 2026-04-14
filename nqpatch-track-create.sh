#!/bin/bash
set -euo pipefail

# nqpatch track create: Create tracking metadata for patches
# Usage: nqpatch track create old.nq new.nq [patch.rdfp[.gz|.bz2]]
#
# Creates:
#   old.sha1, new.sha1, patch.sha1 (hash files)
#   patch.sha1-from (same hash as old.sha1)
#   patch.sha1-to   (same hash as new.sha1)
#
# Patch output compression is auto-detected from file extension:
#   .gz  -> gzip
#   .bz2 -> bzip2
#   .xz  -> xz
#   .zst -> zstd
#   (none) -> plain text

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# Detect compression tool from file extension
## TODO if lbzip2 is absent then fallback to bzip2
detect_compressor() {
    local file="$1"
    case "$file" in
        *.gz)  echo "gzip" ;;
        *.bz2) echo "lbzip2" ;;
        *.xz)  echo "xz" ;;
        *.zst) echo "zstd" ;;
        *)     echo "cat" ;;
    esac
}

# Get file extension with a leading dot. e.g. '.gz'. Empty string if no extension found.
get_file_extension() {
    local base=$(basename -- "$1")
    # XXX perhaps: base=$(basename -- "$1" 2>/dev/null) || return 1
    local ext="${base##*.}"
    [[ -n "$ext" && "$base" == *.* && "$ext" != "$base" ]] && printf '.%s' "$ext"
}

# Detect decompressor from file extension (for reading)
detect_decompressor() {
    echo "zcat -f"
#    local file="$1"
#    case "$file" in
#        *.gz|*.bz2|*.xz|*.zst) echo "zcat" ;;
#        *)                     echo "cat" ;;
#    esac
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
[[ -f "$OLD_FILE" ]] || { echo "Error: old file not found: $OLD_FILE" >&2; exit 1; }
[[ -f "$NEW_FILE" ]] || { echo "Error: new file not found: $NEW_FILE" >&2; exit 1; }
[[ -n "$PATCH_FILE" ]] || { echo "Error: no patch file specified" >&2; exit 1; }
[[ ! -f "$PATCH_FILE" ]] || { echo "Error: patch file already exists: $PATCH_FILE" >&2; exit 1; }

create_sha1_meta_file() {
    local file="$1"
    local meta_file="$2"
    local sha1=""

    # Load the 'sha1' field from an existing .meta.json file
    [ -f "$meta_file" ] && sha1=$(jq -r '.sha1 // empty' "$meta_file")

    if [ -z "$sha1" ]; then
        echo "Computing checksum and updating $meta_file" >&2
        local oldJson="{}"
        [ -f "$meta_file" ] && oldJson=$(cat "$meta_file" | jq)
        sha1=$(sha1sum "$file" | awk '{print $1}')
        local newJson=$(jq -n --argjson existing "$oldJson" --arg sha1 "$sha1" '$existing | .sha1 = $sha1')
        echo "$newJson" | jq > "$meta_file"
    fi
    echo "$sha1"
}

# Generate or verify patch file

echo "Generating patch file $PATCH_FILE" >&2

COMPRESSOR=$(detect_compressor "$PATCH_FILE")

# Create patch to a tmp file first in case the process gets interrupted.
"$SCRIPT_DIR/nqpatch" "create" "$OLD_FILE" "$NEW_FILE" | $COMPRESSOR > "${PATCH_FILE}.tmp"
mv "${PATCH_FILE}.tmp" "$PATCH_FILE"

OLD_META_FILE="${OLD_FILE}.meta.json"
NEW_META_FILE="${NEW_FILE}.meta.json"

OLD_SHA1=$(create_sha1_meta_file "$OLD_FILE" "$OLD_META_FILE")
NEW_SHA1=$(create_sha1_meta_file "$NEW_FILE" "$NEW_META_FILE")
# Note: patch file will remain; caller should clean up if needed

# Create patch.sha1
# PATCH_SHA1_FILE="${PATCH_FILE}.sha1"
PATCH_META_FILE="${PATCH_FILE}.meta.json"
PATCH_SHA1=$(create_sha1_meta_file "$PATCH_FILE" "$PATCH_META_FILE")

# Create patch.sha1-from and patch.sha1-to
oldJson=$(cat "$PATCH_META_FILE" | jq)
newJson=$(jq -n --argjson existing "$oldJson" --arg from "$OLD_SHA1" --arg to "$NEW_SHA1" '$existing | ."sha1-from" = $from | ."sha1-to" = $to')
echo "$newJson" > "$PATCH_META_FILE"

echo "Created tracking metadata:" >&2
#echo "  ${OLD_FILE}.sha1    ($OLD_SHA1)" >&2
#echo "  ${NEW_FILE}.sha1    ($NEW_SHA1)" >&2
#echo "  ${PATCH_FILE}.sha1  ($(cat $PATCH_SHA1_FILE))" >&2
echo "# $OLD_META_FILE" >&2
echo "$(cat "$OLD_META_FILE")" >&2
echo "# $NEW_META_FILE" >&2
echo "$(cat "$NEW_META_FILE")" >&2
echo "# $PATCH_META_FILE" >&2
echo "$(cat "$PATCH_META_FILE")" >&2

