#!/usr/bin/env bats

setup() {
  load '../test_helper'
  GIT_RECENT="$DOTFILES_ROOT/bin/git-recent"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  unset GIT_PAGER
}

init_repo() {
  git init "$REPO" --quiet --initial-branch=main
  REPO="$(cd "$REPO" && pwd -P)"
  cd "$REPO"
  git config user.name "Test User"
  git config user.email "test@example.com"
  GIT_AUTHOR_DATE="@900000000 +0000" GIT_COMMITTER_DATE="@900000000 +0000" \
    git commit --allow-empty -m "init" --quiet
}

make_branch() {
  local name="$1" ts="$2" subj="${3:-touch $name}"
  git checkout -q -b "$name"
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
    git commit --allow-empty -m "$subj" --quiet
  git checkout -q main
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

@test "lists branches newest-first when piped (plain refnames)" {
  init_repo
  make_branch oldest 1000000000
  make_branch middle 1100000000
  make_branch newest 1200000000
  run "$GIT_RECENT"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "newest" ]
  [ "${lines[1]}" = "middle" ]
  [ "${lines[2]}" = "oldest" ]
  # main was the initial commit at "now" — should appear too
  [[ " ${lines[*]} " == *" main "* ]]
}

@test "no branches → exit 0, empty output" {
  # Empty git repo with no commits has no branches yet
  git init "$REPO" --quiet --initial-branch=main
  cd "$REPO"
  run "$GIT_RECENT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}
