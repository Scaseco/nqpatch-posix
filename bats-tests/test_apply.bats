#!/usr/bin/env bats

setup() {
  export SCRIPTS_DIR="$BATS_TEST_DIRNAME"
  export TEMP_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEMP_DIR"
}

# Helper to create temp files
create_file() {
  local filename="$1"
  shift
  printf "%s\n" "$@" > "$TEMP_DIR/$filename"
}

create_patch() {
  local filename="$1"
  shift
  printf "%s\n" "$@" > "$TEMP_DIR/$filename"
}

@test "apply: single patch from snapshot1 to snapshot2" {
  create_file "base.nq" "b" "c" "d"
  create_patch "patch.rdfp" "A a" "D b" "D d" "A e"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "apply" \
    "$TEMP_DIR/base.nq" \
    "$TEMP_DIR/patch.rdfp"
  
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'a\nc\ne\n')" ]
}

@test "apply: sequential patches to reach snapshot3" {
  create_file "base.nq" "b" "c" "d"
  create_patch "patch1.rdfp" "A a" "D b" "D d" "A e"
  create_patch "patch2.rdfp" "D a" "D c" "A f"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "apply" \
    "$TEMP_DIR/base.nq" \
    "$TEMP_DIR/patch1.rdfp" \
    "$TEMP_DIR/patch2.rdfp"
  
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'e\nf\n')" ]
}

@test "apply: merged patch produces same result as sequential" {
  create_file "base.nq" "b" "c" "d"
  create_patch "patch1.rdfp" "A a" "D b" "D d" "A e"
  create_patch "patch2.rdfp" "D a" "D c" "A f"
  
  # Apply sequentially
  run bash "$SCRIPTS_DIR/../nqpatch" "apply" \
    "$TEMP_DIR/base.nq" \
    "$TEMP_DIR/patch1.rdfp" \
    "$TEMP_DIR/patch2.rdfp"
  [ "$status" -eq 0 ]
  sequential_result="$output"
  
  # Merge then apply
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$TEMP_DIR/patch1.rdfp" \
    "$TEMP_DIR/patch2.rdfp"
  [ "$status" -eq 0 ]
  merged_patch="$output"
  
  echo "$merged_patch" > "$TEMP_DIR/merged.rdfp"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "apply" \
    "$TEMP_DIR/base.nq" \
    "$TEMP_DIR/merged.rdfp"
  [ "$status" -eq 0 ]
  merged_result="$output"
  
  [ "$sequential_result" = "$merged_result" ]
}

@test "apply: test2 stable sort - A->D->A should result in x being added" {
  create_file "base.nq" "y"
  create_patch "p1.rdfp" "A x"
  create_patch "p2.rdfp" "D x"
  create_patch "p3.rdfp" "A x"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "apply" \
    "$TEMP_DIR/base.nq" \
    "$TEMP_DIR/p1.rdfp" \
    "$TEMP_DIR/p2.rdfp" \
    "$TEMP_DIR/p3.rdfp"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "x"
  echo "$output" | grep -q "y"
}

@test "apply: no base file shows usage" {
  run bash "$SCRIPTS_DIR/../nqpatch" "apply"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Usage:"
}
