#!/bin/bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "${1:-}" in
  create) shift; exec "${SCRIPT_DIR}/nqpatch-track-create.sh" "$@" ;;
  "")     echo "Usage: $0 {create} [args...]" >&2; exit 1 ;;
  *)      echo "Usage: $0 {create} [args...]" >&2; exit 1 ;;
esac
