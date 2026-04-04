#!/bin/bash

# This creates a sorted .rdfp patch (A/D-prefixed lines) from two sorted .nq files.
# ⚠️ Byte-level diff: expects identical whitespace, encoding, and line endings.

OLD="$1"
NEW="$2"

if [ -z "$OLD" -o -z "$NEW" ]; then
  echo "Usage: $0 old.sorted.nq new.sorted.nq → patch.sorted.rdfp"
  echo
  echo "Create a sorted .rdfp patch (A/D lines) by byte-level diff of two sorted .nq files."
  echo
  echo "⚠️  Ensure identical indent, spacing, line endings and RDF term serialization."
  echo "   Differences may be misinterpreted as data changes!"
  echo
  echo "💡 When in doubt, canonicalize first with e.g. rapper."
  echo
  echo "💡 Pro-Tip: Use process substitution for compressed/encoded input:"
  echo "  $0 <(lbzcat old.sorted.nq.bz2) <(lbzcat new.sorted.nq.bz2) > patch.sorted.rdfp"
  exit 1
fi

# Lines start with A (added) and D (deleted) according to:
# https://afs.github.io/rdf-delta/rdf-patch.html

LC_ALL=C comm -3 "$OLD" "$NEW" | awk '
  /^[^\t]/     { print "D " $0; next }   # No leading tab -> only in file1 (removed)
  /^\t[^\t]/   { sub(/^\t/, "", $0); print "A " $0 }  # One leading tab -> only in file2 (added)
'

