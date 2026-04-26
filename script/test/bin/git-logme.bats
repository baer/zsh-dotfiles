#!/usr/bin/env bats

setup() {
  load '../test_helper'
  LOGME="$DOTFILES_ROOT/bin/git-logme"

  # Create a temp gitconfig that includes the work fixture via a relative path.
  TEMP_CONFIG="$BATS_TEST_TMPDIR/gitconfig"
  mkdir -p "$BATS_TEST_TMPDIR/included"
  cp "$FIXTURES_DIR/gitconfig.logme-main" "$TEMP_CONFIG"
  cp "$FIXTURES_DIR/gitconfig.logme-work" "$BATS_TEST_TMPDIR/included/gitconfig.logme-work"

  printf '\n[include]\n\tpath = included/gitconfig.logme-work\n' >> "$TEMP_CONFIG"

  # Point git at our temp config instead of the real global
  export GIT_CONFIG_GLOBAL="$TEMP_CONFIG"

  git init --initial-branch=main "$BATS_TEST_TMPDIR/repo" --quiet
  cd "$BATS_TEST_TMPDIR/repo"
  git config user.name "Repo User"
  git config user.email "repo@example.com"

  make_commit "Test User" "test@example.com" \
    "2026-04-18T09:00:00 -0700" "2026-04-18T09:00:00 -0700" \
    "old test commit"
  make_commit "Test User" "test@example.com" \
    "2026-04-25T09:00:00 -0700" "2026-04-25T09:00:00 -0700" \
    "recent test commit"
  make_commit "Test User" "test@example.com" \
    "2024-01-02T09:00:00 -0800" "2026-04-25T12:00:00 -0700" \
    "author date check"

  git checkout -b feature --quiet
  make_commit "Work User" "work@corp.com" \
    "2026-04-25T13:00:00 -0700" "2026-04-25T13:00:00 -0700" \
    "feature work"

  git checkout main --quiet
  make_commit "Test User" "test@example.com" \
    "2026-04-25T14:00:00 -0700" "2026-04-25T14:00:00 -0700" \
    "main side"
  GIT_AUTHOR_NAME="Test User" \
    GIT_AUTHOR_EMAIL="test@example.com" \
    GIT_AUTHOR_DATE="2026-04-25T15:00:00 -0700" \
    GIT_COMMITTER_NAME="Test User" \
    GIT_COMMITTER_EMAIL="test@example.com" \
    GIT_COMMITTER_DATE="2026-04-25T15:00:00 -0700" \
    git merge --no-ff feature -m "merge feature" --quiet
}

make_commit() {
  local name="$1" email="$2" author_date="$3" committer_date="$4" subject="$5"

  GIT_AUTHOR_NAME="$name" \
    GIT_AUTHOR_EMAIL="$email" \
    GIT_AUTHOR_DATE="$author_date" \
    GIT_COMMITTER_NAME="$name" \
    GIT_COMMITTER_EMAIL="$email" \
    GIT_COMMITTER_DATE="$committer_date" \
    git commit --allow-empty -m "$subject" --quiet
}

@test "--list shows identities from global config" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Test User"* ]]
  [[ "${output}" == *"test@example.com"* ]]
}

@test "--list shows identities from included configs" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Work User"* ]]
  [[ "${output}" == *"work@corp.com"* ]]
  [[ "${output}" == *"included/gitconfig.logme-work"* ]]
}

@test "--list shows identities from repo-local config" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Repo User"* ]]
  [[ "${output}" == *"repo@example.com"* ]]
  [[ "${output}" == *".git/config"* ]]
}

@test "--list prints header line" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "git-logme: discovered identities:" ]]
}

@test "-l is an alias for --list" {
  run "$LOGME" -l
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Test User"* ]]
}

@test "exits 1 with message when no identities found" {
  # Empty gitconfig with no user section
  printf '[core]\n\tbare = false\n' > "$TEMP_CONFIG"
  git config --unset-all user.name
  git config --unset-all user.email
  run "$LOGME" --list
  [ "$status" -eq 1 ]
  [[ "${output}" == *"no user identities found"* ]]
}

@test "-h prints usage and exits 0" {
  run "$LOGME" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git logme"* ]]
  [[ "${output}" == *"--days <n>"* ]]
  [[ "${output}" == *"--no-merges"* ]]
  [[ "${output}" == *"--author-date"* ]]
}

@test "--days limits commits to the requested number of days" {
  run "$LOGME" --days 3 --format=%s
  [ "$status" -eq 0 ]
  [[ "${output}" == *"recent test commit"* ]]
  [[ "${output}" == *"feature work"* ]]
  [[ "${output}" != *"old test commit"* ]]
}

@test "--days rejects zero" {
  run "$LOGME" --days 0
  [ "$status" -eq 1 ]
  [[ "${output}" == *"--days must be at least 1"* ]]
}

@test "conflicting range flags fail clearly" {
  run "$LOGME" --today --week
  [ "$status" -eq 1 ]
  [[ "${output}" == *"conflicting range flags: --today and --week"* ]]
}

@test "--no-merges excludes merge commits" {
  run "$LOGME" --no-merges --format=%s
  [ "$status" -eq 0 ]
  [[ "${output}" != *"merge feature"* ]]
  [[ "${output}" == *"feature work"* ]]
  [[ "${output}" == *"main side"* ]]
}

@test "--author-date uses author date in default format" {
  run "$LOGME" --grep="author date check" --date=format:%Y-%m-%d
  [ "$status" -eq 0 ]
  [[ "${output}" == *"2026-04-25"* ]]
  [[ "${output}" != *"2024-01-02"* ]]

  run "$LOGME" --author-date --grep="author date check" --date=format:%Y-%m-%d
  [ "$status" -eq 0 ]
  [[ "${output}" == *"2024-01-02"* ]]
  [[ "${output}" != *"2026-04-25"* ]]
}

@test "passthrough format flags suppress the default format" {
  run "$LOGME" --format=%an:%s --grep="feature work"
  [ "$status" -eq 0 ]
  [ "$output" = "Work User:feature work" ]
}
