#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
}

# --- _is_cask_skipped ---

@test "_is_cask_skipped returns 0 when cask is in skip list" {
  export HOMEBREW_BUNDLE_CASK_SKIP="slack zoom firefox"
  run _is_cask_skipped "zoom"
  [ "$status" -eq 0 ]
}

@test "_is_cask_skipped returns 1 when cask is not in skip list" {
  export HOMEBREW_BUNDLE_CASK_SKIP="slack zoom"
  run _is_cask_skipped "firefox"
  [ "$status" -eq 1 ]
}

@test "_is_cask_skipped returns 1 when skip list is empty" {
  unset HOMEBREW_BUNDLE_CASK_SKIP
  run _is_cask_skipped "firefox"
  [ "$status" -eq 1 ]
}

@test "_is_cask_skipped does not partial match" {
  export HOMEBREW_BUNDLE_CASK_SKIP="firefox-nightly"
  run _is_cask_skipped "firefox"
  [ "$status" -eq 1 ]
}

# --- _is_mas_skipped ---

@test "_is_mas_skipped returns 0 when id is in skip list" {
  export HOMEBREW_BUNDLE_MAS_SKIP="409183694 497799835"
  run _is_mas_skipped "497799835"
  [ "$status" -eq 0 ]
}

@test "_is_mas_skipped returns 1 when id is not in skip list" {
  export HOMEBREW_BUNDLE_MAS_SKIP="409183694"
  run _is_mas_skipped "497799835"
  [ "$status" -eq 1 ]
}

@test "_is_mas_skipped returns 1 when skip list is empty" {
  unset HOMEBREW_BUNDLE_MAS_SKIP
  run _is_mas_skipped "409183694"
  [ "$status" -eq 1 ]
}

# --- _is_audit_ignored ---

@test "_is_audit_ignored returns 0 when package is in ignore file" {
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/ignore"
  printf "slack\nzoom\nfirefox\n" > "$AUDIT_IGNORE_FILE"
  run _is_audit_ignored "zoom"
  [ "$status" -eq 0 ]
}

@test "_is_audit_ignored returns 1 when package is not in ignore file" {
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/ignore"
  printf "slack\nzoom\n" > "$AUDIT_IGNORE_FILE"
  run _is_audit_ignored "firefox"
  [ "$status" -eq 1 ]
}

@test "_is_audit_ignored returns 1 when ignore file does not exist" {
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/nonexistent"
  run _is_audit_ignored "slack"
  [ "$status" -eq 1 ]
}
