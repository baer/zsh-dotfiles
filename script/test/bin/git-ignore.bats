#!/usr/bin/env bats

setup() {
  load '../test_helper'
  GIT_IGNORE="$DOTFILES_ROOT/bin/git-ignore"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
}

init_repo() {
  git init "$REPO" --quiet
  REPO="$(cd "$REPO" && pwd -P)"
  cd "$REPO"
  git config user.name "Test User"
  git config user.email "test@example.com"
}

@test "-h prints usage and exits 0" {
  run "$GIT_IGNORE" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git ignore"* ]]
}

@test "--help prints usage and exits 0" {
  run "$GIT_IGNORE" --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git ignore"* ]]
}

@test "path -l returns the local .gitignore path" {
  init_repo
  run "$GIT_IGNORE" path -l
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.gitignore" ]
}

@test "path -p returns the .git/info/exclude path" {
  init_repo
  run "$GIT_IGNORE" path -p
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.git/info/exclude" ]
}

@test "path defaults to local scope when no scope flag is given" {
  init_repo
  run "$GIT_IGNORE" path
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.gitignore" ]
}

@test "path -g respects core.excludesFile" {
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global-config"
  : > "$GIT_CONFIG_GLOBAL"
  git config --global core.excludesFile "$BATS_TEST_TMPDIR/myignore"
  run "$GIT_IGNORE" path -g
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/myignore" ]
}

@test "path -g falls back to ~/.gitignore when core.excludesFile is unset" {
  HOME="$BATS_TEST_TMPDIR/home" mkdir -p "$BATS_TEST_TMPDIR/home"
  : > "$BATS_TEST_TMPDIR/home/.gitignore"
  HOME="$BATS_TEST_TMPDIR/home" run "$GIT_IGNORE" path -g
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/home/.gitignore" ]
}

@test "path -g falls back to XDG_CONFIG_HOME when neither is set" {
  local empty_home="$BATS_TEST_TMPDIR/empty-home"
  mkdir -p "$empty_home"
  HOME="$empty_home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
    run "$GIT_IGNORE" path -g
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/xdg/git/ignore" ]
}

@test "path -l outside a repo exits 2" {
  cd "$BATS_TEST_TMPDIR"
  run "$GIT_IGNORE" path -l
  [ "$status" -eq 2 ]
  [[ "$output" == *"not in a git repo"* ]]
}

@test "conflicting scope flags exit 1" {
  init_repo
  run "$GIT_IGNORE" path -l -g
  [ "$status" -eq 1 ]
  [[ "$output" == *"conflicting scope"* ]]
}

@test "unknown subcommand exits 1" {
  run "$GIT_IGNORE" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "add writes patterns to .gitignore" {
  init_repo
  run "$GIT_IGNORE" add node_modules .env
  [ "$status" -eq 0 ]
  [ -f "$REPO/.gitignore" ]
  grep -Fxq "node_modules" "$REPO/.gitignore"
  grep -Fxq ".env" "$REPO/.gitignore"
}

@test "add prints a stderr summary by default" {
  init_repo
  run "$GIT_IGNORE" add node_modules
  [ "$status" -eq 0 ]
  [[ "$output" == *"added 1 pattern to .gitignore"* ]]
}

@test "add -q suppresses the summary" {
  init_repo
  run "$GIT_IGNORE" -q add node_modules
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "add is idempotent on duplicate patterns" {
  init_repo
  printf 'node_modules\n' > "$REPO/.gitignore"
  before=$(md5sum < "$REPO/.gitignore")
  run "$GIT_IGNORE" add node_modules
  [ "$status" -eq 0 ]
  after=$(md5sum < "$REPO/.gitignore")
  [ "$before" = "$after" ]
}

@test "add reports duplicates in the summary" {
  init_repo
  printf 'node_modules\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" add node_modules .env
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 already present"* ]]
}

@test "add appends a trailing newline before writing" {
  init_repo
  printf 'existing-line' > "$REPO/.gitignore"   # no trailing \n
  run "$GIT_IGNORE" add new-line
  [ "$status" -eq 0 ]
  [ "$(cat "$REPO/.gitignore")" = "$(printf 'existing-line\nnew-line')" ]
  # Verify the file actually ends with a newline (command substitution can't see this)
  last_byte=$(tail -c 1 "$REPO/.gitignore" | od -An -tx1 | tr -d ' ')
  [ "$last_byte" = "0a" ]
}

@test "add creates the file if missing" {
  init_repo
  [ ! -e "$REPO/.gitignore" ]
  run "$GIT_IGNORE" add foo
  [ "$status" -eq 0 ]
  [ -f "$REPO/.gitignore" ]
}

@test "add -p creates .git/info/exclude path" {
  init_repo
  rm -f "$REPO/.git/info/exclude"
  run "$GIT_IGNORE" add -p '*.tmp'
  [ "$status" -eq 0 ]
  grep -Fxq '*.tmp' "$REPO/.git/info/exclude"
}
