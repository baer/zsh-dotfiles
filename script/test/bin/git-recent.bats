#!/usr/bin/env bats

setup() {
  load '../test_helper'
  GIT_RECENT="$DOTFILES_ROOT/bin/git-recent"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  unset GIT_PAGER
}

@test "-h prints usage and exits 0" {
  run "$GIT_RECENT" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git recent"* ]]
}

@test "--help prints usage and exits 0" {
  run "$GIT_RECENT" --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git recent"* ]]
}

@test "unknown flag exits 1 with helpful error" {
  run "$GIT_RECENT" --frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option"* ]]
}
