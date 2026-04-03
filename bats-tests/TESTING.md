# Test Infrastructure for rdfpatch-nq-posix

## Overview

This directory contains Bats (Bash Automated Testing System) test suites for the three main scripts:
- `rdfpatch-nq-create.sh` - Create patches from N-Quads snapshots
- `rdfpatch-nq-apply.sh` - Apply patches to N-Quads files
- `rdfpatch-nq-merge.sh` - Merge multiple patches

## Test Files

- `test_merge.bats` - Tests for the merge script (8 tests)
- `test_create.bats` - Tests for the create script (4 tests)
- `test_apply.bats` - Tests for the apply script (5 tests)

**Total: 17 tests**

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
```

## Test Coverage

### merge tests
1. **Stable sort preserves operation order**: A→D→A = A (main fix verification)
2. **Five patches**: A→D→A→D→A = A
3. **Six patches**: A→D→A→D→A→D = nothing (all cancel)
4. **Multiple triples**: Verifies stable sort works with different payloads
5. **Existing test patches**: Validates against original test data
6. **Empty patches**: Handles empty input gracefully
7. **Single patch**: Works with just one patch file
8. **No arguments**: Shows usage message

### create tests
1. **Patch from snapshot1→snapshot2**: Verifies correct A/D output
2. **Patch from snapshot2→snapshot3**: Another verification
3. **No arguments**: Shows usage message
4. **Missing second argument**: Shows usage message

### apply tests
1. **Single patch**: Applies one patch correctly
2. **Sequential patches**: Applies multiple patches in order
3. **Merged patch = sequential**: Verifies merge produces same result
4. **Stable sort integration**: Tests that merge fix works with apply
5. **No base file**: Shows usage message

## Requirements

### bats-core
Install via apt or npm:

```bash
apt-get install -y bats
```

Or install via npm:

```bash
npm install -g bats-core
```

The test runner (`run-tests.sh`) will try to find bats in common locations.

## Adding New Tests

1. Add a new `@test` block in the appropriate file
2. Use `create_file()` or `create_patch()` for inline data
3. Reference existing test data with `$SCRIPTS_DIR/../test/...`
4. Verify output matches expected results

Example:
```bash
@test "new test case" {
  create_patch "test.rdfp" "A x" "D y"
  
  run bash "$SCRIPTS_DIR/../rdfpatch-nq-merge.sh" "$TEMP_DIR/test.rdfp"
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "A x"
}
```

## Bug Fixes

### Fixed: rdfpatch-nq-apply.sh (line 40-46)
The script had a quoting issue when building command strings with multiple patches. The fix uses `printf '%q'` to properly escape arguments for `eval`.

### Fixed: rdfpatch-nq-merge.sh (line 17)
Added `-s` flag to `sort -m` for stable sorting, preserving the relative order of operations on the same triple across different patch files.

## CI Integration

For GitHub Actions on Ubuntu, use apt to install bats:

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install bats
        run: |
          sudo apt-get update
          sudo apt-get install -y bats
      - name: Run tests
        run: ./bats-tests/run-tests.sh
```
