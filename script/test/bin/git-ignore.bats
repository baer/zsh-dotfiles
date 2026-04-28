#!/usr/bin/env bats

setup() {
  load '../test_helper'
  GIT_IGNORE="$DOTFILES_ROOT/bin/git-ignore"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
}

init_repo() {
  git init "$REPO" --quiet
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
