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

@test "track create: creates hash files and from/to-sha1" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
      "$TEMP_DIR/old.nq" \
      "$TEMP_DIR/new.nq" \
      "$TEMP_DIR/patch.rdfp"

  [ "$status" -eq 0 ]
  [ -f "$TEMP_DIR/old.nq.sha1" ]
  [ -f "$TEMP_DIR/new.nq.sha1" ]
  [ -f "$TEMP_DIR/patch.rdfp" ]
  [ -f "$TEMP_DIR/patch.rdfp.sha1" ]
  [ -f "$TEMP_DIR/patch.rdfp.from-sha1" ]
  [ -f "$TEMP_DIR/patch.rdfp.to-sha1" ]

  grep -q "A a" "$TEMP_DIR/patch.rdfp"
  grep -q "D b" "$TEMP_DIR/patch.rdfp"
  grep -q "D d" "$TEMP_DIR/patch.rdfp"
  grep -q "A e" "$TEMP_DIR/patch.rdfp"
}

@test "track create: from-sha1 and to-sha1 files contain correct hashes" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  
  bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
      "$TEMP_DIR/old.nq" \
      "$TEMP_DIR/new.nq" \
      "$TEMP_DIR/patch.rdfp"
  
  from_sha1=$(cat "$TEMP_DIR/patch.rdfp.from-sha1")
  to_sha1=$(cat "$TEMP_DIR/patch.rdfp.to-sha1")
  
  old_sha1=$(cat "$TEMP_DIR/old.nq.sha1")
  new_sha1=$(cat "$TEMP_DIR/new.nq.sha1")
  
  [ "$from_sha1" = "$old_sha1" ]
  [ "$to_sha1" = "$new_sha1" ]
}

@test "track create: does not overwrite existing hash files" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  
  # Pre-create hash files with specific content
  echo "oldhash123" > "$TEMP_DIR/old.nq.sha1"
  echo "newhash456" > "$TEMP_DIR/new.nq.sha1"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq" \
    "$TEMP_DIR/patch.rdfp"
  
  [ "$status" -eq 0 ]
  # Hash files should retain original content (not be overwritten)
  [ "$(cat "$TEMP_DIR/old.nq.sha1")" = "oldhash123" ]
  [ "$(cat "$TEMP_DIR/new.nq.sha1")" = "newhash456" ]
}

@test "track: usage shows help" {
  run bash "$SCRIPTS_DIR/../nqpatch" "track"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Usage:"
}

@test "track create: missing old file shows error" {
  create_file "new.nq" "a" "c" "e"
  create_patch "patch.rdfp" "A a" "D b" "D d" "A e"
  
 run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq" \
    "$TEMP_DIR/patch.rdfp"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Error:"
}

@test "track create: missing new file shows error" {
  create_file "old.nq" "b" "c" "d"
  create_patch "patch.rdfp" "A a" "D b" "D d" "A e"
  
 run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/nonexistent.nq" \
    "$TEMP_DIR/patch.rdfp"
  
  [ "$status" -eq 1 ]
  echo "$output" | grep -q "Error:"
}
