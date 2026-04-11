# Test Infrastructure for nqpatch-posix

## Overview

This directory contains Bats (Bash Automated Testing System) test suites for the four main scripts (via the entry point `nqpatch`):
- `nqpatch-create.sh` - Create patches from N-Quads snapshots
- `nqpatch-apply.sh` - Apply patches to N-Quads files
- `nqpatch-merge.sh` - Merge multiple patches
- `nqpatch-track-create.sh` - Create tracking metadata for patches

## Running Tests

```bash
cd bats-tests
./run-tests.sh
```

Or run individual test files:

```bash
bats test_merge.bats
bats test_create.bats
bats test_apply.bats
bats test_track.bats
```

## Test Structure

### test\_merge.bats
Tests for the merge script:
- Stable sort preserves operation order
- Multiple operations on same triple
- Multiple triples with stable sort
- Existing test patches
- Edge cases (empty patches, single patch, no arguments)

### test\_create.bats
Tests for the create script:
- Patch creation from snapshots
- Comparison with expected A/D operations
- Usage error handling

### test\_apply.bats
Tests for the apply script:
- Single patch application
- Sequential patch application
- Merged patch produces same result as sequential
- Stable sort integration
- Usage error handling

### test\_track.bats
Tests for the track create script:
- Creates hash files (.sha1) and from/sha1-from tracking files
- sha1-from and sha1-to files contain correct snapshot hashes
- Does not overwrite existing hash files
- Usage help display
- Error handling for missing input files

## Test Data Strategy

### Inline Data (Herodocs)
Small test cases use `create_file()` and `create_patch()` helpers that write data to a temporary directory. This keeps tests self-contained and avoids file I/O overhead.

### Existing Test Data
Larger tests reuse the existing `test/` directory files (snapshot1.nq, patch-1-to-2.rdfp, etc.) to validate against known good data.

## Requirements

- Bats: Install via e.g. `apt-get install -y bats` or `npm install -g bats-core` or see [bats-core/bats](https://github.com/bats-core/bats-core).

## Adding New Tests

1. Add a new `@test` block in the appropriate file
2. Use `create_file()` or `create_patch()` for inline data
3. Reference existing test data with `$SCRIPTS_DIR/test/...`
4. Verify output matches expected results

Example:
```bash
@test "new test case" {
  create_patch "test.rdfp" "A x" "D y"
  
  run bash "$SCRIPTS_DIR/../nqpatch-merge.sh" "$TEMP_DIR/test.rdfp"
  [ "$status" -eq 0 ]
  [[ "$output" == *"A x"* ]]
}
```
