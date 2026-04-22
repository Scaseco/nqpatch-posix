#!/bin/bash
set -euo pipefail

# nqpatch track sort: Create tracking metadata while producing a sorted dump
# from an unsorted one.
# Usage: nqpatch track sort unsorted.nq[.fmt1] sorted.nq[.fmt2] [SORT_OPTIONS]
#
# Creates:
#   sorted.nq[.fmt2].sha1 (sorted dump)
#   unsorted.nq[.fmt1].sha1, sorted[.fmt2].nq.sha1 (hash files)
#
# SORT_OPTIONS are directly passed to the sort command. Can be used to e.g.
#   specify the allowed memory size with -S 16G
#
# Patch output compression is auto-detected from file extension:
#   .gz  -> gzip
#   .bz2 -> bzip2
#   .xz  -> xz
#   .zst -> zstd
#   (none) -> plain text

# TODO Future features:
# * --rehash to force updating the hashes (updates hashes in the .meta.json file)
# * --force to sort the data (even if apparently already sorted), implies --rehash
# * Script should refuse to hash git lfs links!

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
# Does not count hidden files ('.hidden') as file extensions.
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

# Resolves a file argument to a command string that streams its decoded content
stream_cmd() { printf 'zcat -f -- %q' "$1"; }

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 unsorted{.nt|.nq}[.fmt] sorted{.nt|.nq}[.fmt2]" >&2
    echo "" >&2
    echo "Create tracking metadata for a dump sort operation." >&2
    echo "If patch is not provided, it will be generated automatically." >&2
    echo "Compression is auto-detected from patch filename extension." >&2
    exit 1
fi

OLD_FILE="$1"
NEW_FILE="$2"
#OLD_SHA1_FILE="$OLD_FILE.sha1"
#NEW_SHA1_FILE="$NEW_FILE.sha1"

OLD_META_FILE="${OLD_FILE}.meta.json"
NEW_META_FILE="${NEW_FILE}.meta.json"

SORT_OPTIONS=("${@:3}") # E.g. -S80g

# Verify input files exist
[[ -f "$OLD_FILE" ]] || { echo "Error: old file not found: $OLD_FILE" >&2; exit 1; }
# [[ ! -f "$NEW_FILE" ]] || { echo "Error: file already exits: $NEW_FILE" >&2; exit 1; }

# Create SHA1 hash files if absent.
create_sha1_file_old() {
    local file="$1"
    local sha1_file="${2:-${file}.sha1}"
    local sha1
    
    if [ ! -f "$sha1_file" ]; then
        echo "Generating $sha1_file" >&2
        local sha1=$(sha1sum "$file" | awk '{print $1}')
        echo "$sha1" > "$sha1_file"
    else
        sha1=$(cat "$sha1_file")
    fi
}

# New, more general approach with a .meta.json file.
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

# Create sha1 as sibling to the old file
echo "Hashing $OLD_FILE ..." >&2
# create_sha1_file "$OLD_FILE" "$OLD_SHA1_FILE"
OLD_SHA1=$(create_sha1_meta_file "$OLD_FILE" "$OLD_META_FILE")

COMPRESSOR=$(detect_compressor "$NEW_FILE")
if [ ! -f "$NEW_FILE" ]; then
    echo "Sorting $OLD_FILE and compressing with [$COMPRESSOR]..." >&2
    $(stream_cmd "$OLD_FILE") | LC_ALL=C sort -u ${SORT_OPTIONS[@]} | $COMPRESSOR > "${NEW_FILE}.tmp"
    mv "${NEW_FILE}.tmp" "$NEW_FILE"
else
    echo "File $NEW_FILE already exists." >&2
fi

echo "Hashing $NEW_FILE ..." >&2
# create_sha1_file "$NEW_FILE" "$NEW_SHA1_FILE"
NEW_SHA1=$(create_sha1_meta_file "$NEW_FILE" "$NEW_META_FILE")

# XXX oldJson is a bad name - its the existing state of newJson
oldJson=$(cat "$NEW_META_FILE" | jq)
newJson=$(jq -n --argjson existing "$oldJson" --arg originalSha1 "$OLD_SHA1" '$existing | ."sha1-original" = $originalSha1')
echo "$newJson" > "$NEW_META_FILE"

echo "Completed. Created tracking metadata:" >&2
echo "# $OLD_META_FILE" >&2
echo "$(cat "$OLD_META_FILE")" >&2
echo "# $NEW_META_FILE" >&2
echo "$(cat "$NEW_META_FILE")" >&2

