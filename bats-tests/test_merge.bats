#!/usr/bin/env bats

setup() {
  export SCRIPTS_DIR="$BATS_TEST_DIRNAME"
  export TEMP_DIR=$(mktemp -d)
}

teardown() {
  rm -rf "$TEMP_DIR"
}

# Helper to create temp patch files
create_patch() {
  local filename="$1"
  shift
  printf "%s\n" "$@" > "$TEMP_DIR/$filename"
}

@test "merge: test2 stable sort preserves operation order (A->D->A = A)" {
  create_patch "p1.rdfp" "A x"
  create_patch "p2.rdfp" "D x"
  create_patch "p3.rdfp" "A x"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$TEMP_DIR/p1.rdfp" \
    "$TEMP_DIR/p2.rdfp" \
    "$TEMP_DIR/p3.rdfp"
  
  [ "$status" -eq 0 ]
  [ "$output" = "A x" ]
}

@test "merge: test2 five patches (A->D->A->D->A = A)" {
  create_patch "p1.rdfp" "A x"
  create_patch "p2.rdfp" "D x"
  create_patch "p3.rdfp" "A x"
  create_patch "p4.rdfp" "D x"
  create_patch "p5.rdfp" "A x"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$TEMP_DIR/p1.rdfp" \
    "$TEMP_DIR/p2.rdfp" \
    "$TEMP_DIR/p3.rdfp" \
    "$TEMP_DIR/p4.rdfp" \
    "$TEMP_DIR/p5.rdfp"
  
  [ "$status" -eq 0 ]
  [ "$output" = "A x" ]
}

@test "merge: test2 six patches (A->D->A->D->A->D = nothing)" {
  create_patch "p1.rdfp" "A x"
  create_patch "p2.rdfp" "D x"
  create_patch "p3.rdfp" "A x"
  create_patch "p4.rdfp" "D x"
  create_patch "p5.rdfp" "A x"
  create_patch "p6.rdfp" "D x"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$TEMP_DIR/p1.rdfp" \
    "$TEMP_DIR/p2.rdfp" \
    "$TEMP_DIR/p3.rdfp" \
    "$TEMP_DIR/p4.rdfp" \
    "$TEMP_DIR/p5.rdfp" \
    "$TEMP_DIR/p6.rdfp"
  
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "merge: multiple triples with stable sort" {
  create_patch "p1.rdfp" "A a" "D b"
  create_patch "p2.rdfp" "D a" "A c"
  create_patch "p3.rdfp" "A b" "D c"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$TEMP_DIR/p1.rdfp" \
    "$TEMP_DIR/p2.rdfp" \
    "$TEMP_DIR/p3.rdfp"
  
  [ "$status" -eq 0 ]
  # All operations cancel out: A a + D a = nothing, D b + A b = nothing, A c + D c = nothing
  [ -z "$output" ]
}

@test "merge: existing test patches produce expected result" {
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$SCRIPTS_DIR/../test/patch-1-to-2.rdfp" \
    "$SCRIPTS_DIR/../test/patch-2-to-3.rdfp"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "D b"
  echo "$output" | grep -q "D c"
  echo "$output" | grep -q "D d"
  echo "$output" | grep -q "A e"
  echo "$output" | grep -q "A f"
}

@test "merge: empty patches" {
  create_patch "empty1.rdfp" ""
  create_patch "empty2.rdfp" ""
  
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" \
    "$TEMP_DIR/empty1.rdfp" \
    "$TEMP_DIR/empty2.rdfp"
  
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "merge: single patch" {
  create_patch "single.rdfp" "A x" "D y"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "merge" "$TEMP_DIR/single.rdfp"
  
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "A x"
  echo "$output" | grep -q "D y"
}

@test "merge: no arguments shows usage" {
  run bash "$SCRIPTS_DIR/../nqpatch" "merge"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Usage:"
}
