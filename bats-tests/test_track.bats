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

@test "track create: creates .meta.json files" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  
  run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
      "$TEMP_DIR/old.nq" \
      "$TEMP_DIR/new.nq" \
      "$TEMP_DIR/patch.rdfp"

  [ "$status" -eq 0 ]
  [ -f "$TEMP_DIR/old.nq.meta.json" ]
  [ -f "$TEMP_DIR/new.nq.meta.json" ]
  [ -f "$TEMP_DIR/patch.rdfp" ]
  [ -f "$TEMP_DIR/patch.rdfp.meta.json" ]

  grep -q "A a" "$TEMP_DIR/patch.rdfp"
  grep -q "D b" "$TEMP_DIR/patch.rdfp"
  grep -q "D d" "$TEMP_DIR/patch.rdfp"
  grep -q "A e" "$TEMP_DIR/patch.rdfp"
}

@test "track create: .meta.json files contain correct hashes" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"

  bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
      "$TEMP_DIR/old.nq" \
      "$TEMP_DIR/new.nq" \
      "$TEMP_DIR/patch.rdfp"
  
  sha1_from=$(jq -r '."sha1-from"' "$TEMP_DIR/patch.rdfp.meta.json")
  sha1_to=$(jq   -r '."sha1-to"'   "$TEMP_DIR/patch.rdfp.meta.json")
  
  old_sha1=$(jq  -r '."sha1"' "$TEMP_DIR/old.nq.meta.json")
  new_sha1=$(jq  -r '."sha1"'   "$TEMP_DIR/new.nq.meta.json")

  [ "$sha1_from" = "$old_sha1" ]
  [ "$sha1_to" = "$new_sha1" ]
}

@test "track create: does not overwrite existing .meta.json files" {
  create_file "old.nq" "b" "c" "d"
  create_file "new.nq" "a" "c" "e"
  
  # First run: creates patch and meta files
  run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq" \
    "$TEMP_DIR/patch.rdfp"
  
  [ "$status" -eq 0 ]

  # Capture initial hashes
  local old_sha1_first=$(jq -r '.sha1' "$TEMP_DIR/old.nq.meta.json")
  local new_sha1_first=$(jq -r '.sha1' "$TEMP_DIR/new.nq.meta.json")
  local patch_sha1_first=$(jq -r '.sha1' "$TEMP_DIR/patch.rdfp.meta.json")
  local sha1_from_first=$(jq -r '."sha1-from"' "$TEMP_DIR/patch.rdfp.meta.json")
  local sha1_to_first=$(jq -r '."sha1-to"' "$TEMP_DIR/patch.rdfp.meta.json")

  # Sleep briefly to ensure timestamps would differ if files were rewritten
  sleep 1

  # Second run with same arguments (patch file already exists)
  run bash "$SCRIPTS_DIR/../nqpatch" "track" "create" \
    "$TEMP_DIR/old.nq" \
    "$TEMP_DIR/new.nq" \
    "$TEMP_DIR/patch.rdfp"

  [ "$status" -eq 0 ]

  # Verify .meta.json files were not overwritten (hashes should be identical)
  [ "$(jq -r '.sha1' "$TEMP_DIR/old.nq.meta.json")" = "$old_sha1_first" ]
  [ "$(jq -r '.sha1' "$TEMP_DIR/new.nq.meta.json")" = "$new_sha1_first" ]
  [ "$(jq -r '.sha1' "$TEMP_DIR/patch.rdfp.meta.json")" = "$patch_sha1_first" ]

  # Verify patch metadata relationships are preserved
  [ "$(jq -r '."sha1-from"' "$TEMP_DIR/patch.rdfp.meta.json")" = "$sha1_from_first" ]
  [ "$(jq -r '."sha1-to"' "$TEMP_DIR/patch.rdfp.meta.json")" = "$sha1_to_first" ]
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
