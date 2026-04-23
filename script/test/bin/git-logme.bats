#!/usr/bin/env bats

setup() {
  load '../test_helper'
  LOGME="$DOTFILES_ROOT/bin/git-logme"

  # Create a temp gitconfig that includes the work fixture via includeIf
  TEMP_CONFIG="$BATS_TEST_TMPDIR/gitconfig"
  cp "$FIXTURES_DIR/gitconfig.logme-main" "$TEMP_CONFIG"

  # Append an include pointing to the work fixture
  printf '\n[include]\n\tpath = %s\n' "$FIXTURES_DIR/gitconfig.logme-work" >> "$TEMP_CONFIG"

  # Point git at our temp config instead of the real global
  export GIT_CONFIG_GLOBAL="$TEMP_CONFIG"

  # Init a bare repo so git rev-parse works (--list needs it for repo-local check)
  git init "$BATS_TEST_TMPDIR/repo" --quiet
  cd "$BATS_TEST_TMPDIR/repo"
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
  run "$LOGME" --list
  [ "$status" -eq 1 ]
  [[ "${output}" == *"no user identities found"* ]]
}

@test "-h prints usage and exits 0" {
  run "$LOGME" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git logme"* ]]
}
