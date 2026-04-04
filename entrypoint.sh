#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$1" in
  create) shift; exec "${SCRIPT_DIR}/rdfpatch-nq-create.sh" "$@" ;;
  apply)  shift; exec "${SCRIPT_DIR}/rdfpatch-nq-apply.sh" "$@" ;;
  merge)  shift; exec "${SCRIPT_DIR}/rdfpatch-nq-merge.sh" "$@" ;;
  *)      echo "Usage: $0 {create|apply|merge} [args...]" >&2; exit 1 ;;
esac
