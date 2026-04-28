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

@test "path -l defaults to local even without -l" {
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
  HOME="$BATS_TEST_TMPDIR/empty-home"
  mkdir -p "$HOME"
  HOME="$HOME" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
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
