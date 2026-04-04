#!/bin/bash

# Test runner for nqpatch-posix
# Usage: ./run-tests.sh

set -euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Export SCRIPTS_DIR for bats tests to reference
export SCRIPTS_DIR="$SCRIPT_DIR"

# Check if bats is installed (try common locations)
BATS_CMD=""
if command -v bats &> /dev/null; then
    BATS_CMD="bats"
elif [ -x "/tmp/bats-install/bin/bats" ]; then
    BATS_CMD="/tmp/bats-install/bin/bats"
elif [ -x "/usr/local/bin/bats" ]; then
    BATS_CMD="/usr/local/bin/bats"
fi

if [ -z "$BATS_CMD" ]; then
    echo "Error: bats is not installed."
    echo "Install via: apt-get install -y bats"
    echo "Or: npm install -g bats-core"
    exit 1
fi

# Find all test files
TEST_FILES=("$SCRIPT_DIR"/*.bats)

if [ ${#TEST_FILES[@]} -eq 0 ]; then
    echo "No test files found in $SCRIPT_DIR"
    exit 1
fi

echo "Running tests in: $SCRIPT_DIR"
echo "Found ${#TEST_FILES[@]} test file(s)"
echo ""

"$BATS_CMD" "${TEST_FILES[@]}"
