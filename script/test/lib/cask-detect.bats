#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
}

# --- _cask_app_artifacts ---

@test "_cask_app_artifacts extracts app paths from cask JSON" {
  run _cask_app_artifacts <<< '{"casks":[{"token":"slack","artifacts":[{"app":["Slack.app"]},{"zap":[]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Slack.app" ]
}

@test "_cask_app_artifacts returns empty for cask with no app artifacts" {
  run _cask_app_artifacts <<< '{"casks":[{"token":"some-cli","artifacts":[{"binary":["/usr/local/bin/foo"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

@test "_cask_app_artifacts handles multiple app entries" {
  run _cask_app_artifacts <<< '{"casks":[{"token":"multi","artifacts":[{"app":["App1.app","App2.app"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "App1.app" ]
  [ "${lines[1]}" = "App2.app" ]
}

# --- _cask_uninstall_artifacts ---

@test "_cask_uninstall_artifacts extracts delete paths" {
  run _cask_uninstall_artifacts <<< '{"casks":[{"token":"foo","artifacts":[{"uninstall":[{"delete":["/Applications/Foo.app","/Library/Foo"]}]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "/Applications/Foo.app" ]
  [ "${lines[1]}" = "/Library/Foo" ]
}

@test "_cask_uninstall_artifacts returns empty when no uninstall artifacts" {
  run _cask_uninstall_artifacts <<< '{"casks":[{"token":"bar","artifacts":[{"app":["Bar.app"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

# --- _cask_pkgutil_ids ---

@test "_cask_pkgutil_ids extracts pkgutil receipt IDs" {
  run _cask_pkgutil_ids <<< '{"casks":[{"token":"baz","artifacts":[{"uninstall":[{"pkgutil":"com.example.baz"}]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "com.example.baz" ]
}

@test "_cask_pkgutil_ids handles array of pkgutil IDs" {
  run _cask_pkgutil_ids <<< '{"casks":[{"token":"baz","artifacts":[{"uninstall":[{"pkgutil":["com.example.a","com.example.b"]}]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "com.example.a" ]
  [ "${lines[1]}" = "com.example.b" ]
}

@test "_cask_pkgutil_ids returns empty when no pkgutil artifacts" {
  run _cask_pkgutil_ids <<< '{"casks":[{"token":"bar","artifacts":[{"app":["Bar.app"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}
