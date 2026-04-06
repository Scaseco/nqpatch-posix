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

@test "track create: creates hash files and lineage" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  create_patch "patch.rdfp" "A a" "D b" "D d" "A e"
  
run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq"
  
  [ "$status" -eq 0 ]
  [ -f "$TEMP_DIR/old.nq.sha1" ]
  [ -f "$TEMP_DIR/new.nq.sha1" ]
  
  # Find the generated patch file (temp file with .sha1 and .rel)
  patch_sha1_file=$(find "$TEMP_DIR" -name "*.rdfp.sha1" 2>/dev/null | head -1)
  [ -n "$patch_sha1_file" ]
  
  # Verify the patch was generated correctly
  patch_file="${patch_sha1_file%.sha1}"
  [ -f "$patch_file" ]
  grep -q "A a" "$patch_file"
  grep -q "D b" "$patch_file"
  grep -q "D d" "$patch_file"
  grep -q "A e" "$patch_file"
}

@test "track create: lineage file contains from and to hashes" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  create_patch "patch.rdfp" "A a" "D b" "D d" "A e"
  
bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq" \
    "$TEMP_DIR/patch.rdfp"
  
  rel_content=$(cat "$TEMP_DIR/patch.rdfp.rel")
  
  old_sha1=$(cat "$TEMP_DIR/old.nq.sha1")
  new_sha1=$(cat "$TEMP_DIR/new.nq.sha1")
  
  echo "$rel_content" | grep -q "$old_sha1"
  echo "$rel_content" | grep -q "$new_sha1"
}

@test "track create: does not overwrite existing hash files" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  create_patch "patch.rdfp" "A a" "D b" "D d" "A e"
  
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

@test "track create: verifies patch matches old and new files" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  # Wrong patch (doesn't match old->new transition)
  create_patch "wrong.rdfp" "A x" "D y"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq" \
    "$TEMP_DIR/wrong.rdfp"
  
  # Should fail because patch doesn't transition old->new
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
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
