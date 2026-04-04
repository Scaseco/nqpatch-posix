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

@test "create: patch from snapshot1 to snapshot2" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "A a"
  echo "$output" | grep -q "D b"
  echo "$output" | grep -q "D d"
  echo "$output" | grep -q "A e"
}

@test "create: patch from snapshot2 to snapshot3" {
  create_file "old.nq" "a" "c" "e"
  create_file "new.nq" "e" "f"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "D a"
  echo "$output" | grep -q "D c"
  echo "$output" | grep -q "A f"
}

@test "create: no arguments shows usage" {
  run bash "$SCRIPTS_DIR/../nqpatch" "create"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Usage:"
}

@test "create: missing second argument shows usage" {
  run bash "$SCRIPTS_DIR/../nqpatch" "create" "/nonexistent/file.nq"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Usage:"
}
