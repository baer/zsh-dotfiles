#!/usr/bin/env bats

setup() {
  load '../test_helper'

  export LOGFILE="$BATS_TEST_TMPDIR/brew-audit.log"
  copy_fixture "Brewfile.basic"
  source "$DOTFILES_ROOT/script/lib/adopt.sh"

  export CASK_APPDIR="$BATS_TEST_TMPDIR/Applications"
  mkdir -p "$CASK_APPDIR"
}

@test "_remove_adoptable_cask moves an app bundle to Trash" {
  mkdir -p "$CASK_APPDIR/Docker.app"

  _app_is_running() { return 1; }
  _trash_app() {
    printf '%s\n' "$1" > "$BATS_TEST_TMPDIR/trashed-path"
    return 0
  }

  run _remove_adoptable_cask "docker" "Docker.app"

  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/trashed-path")" = "$CASK_APPDIR/Docker.app" ]
}

@test "_remove_adoptable_cask rejects package-based installs" {
  run _remove_adoptable_cask "docker" "(pkg: com.docker.pkg)"

  [ "$status" -eq 1 ]
}
