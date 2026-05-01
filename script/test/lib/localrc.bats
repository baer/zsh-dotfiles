#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/localrc.sh"
  export LOCALRC_PATH="$BATS_TEST_TMPDIR/.localrc"
}

@test "_localrc_set_managed_var creates a managed block in an empty file" {
  run _localrc_set_managed_var "EDITOR" "hx" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run grep -c '^export EDITOR="hx"' "$LOCALRC_PATH"
  [ "$output" = "1" ]
  run grep -c '^# >>> dotfiles localrc >>>' "$LOCALRC_PATH"
  [ "$output" = "1" ]
  run grep -c '^# <<< dotfiles localrc <<<' "$LOCALRC_PATH"
  [ "$output" = "1" ]
}

@test "_localrc_set_managed_var replaces an existing managed value" {
  printf '%s\n' \
    "# >>> dotfiles localrc >>>" \
    'export EDITOR="hx"' \
    "# <<< dotfiles localrc <<<" > "$LOCALRC_PATH"

  run _localrc_set_managed_var "EDITOR" "zed" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run _localrc_get_managed_value "EDITOR" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [ "$output" = "zed" ]
}

@test "_localrc_write_managed_lines preserves content outside the managed block" {
  printf '%s\n' \
    '# user secret' \
    'export TOKEN="abc123"' \
    '' \
    "# >>> dotfiles localrc >>>" \
    'export EDITOR="hx"' \
    "# <<< dotfiles localrc <<<" \
    '' \
    '# trailing note' > "$LOCALRC_PATH"

  run _localrc_set_managed_var "AGENT" "codex" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *'# user secret'* ]]
  [[ "$output" == *'export TOKEN="abc123"'* ]]
  [[ "$output" == *'export EDITOR="hx"'* ]]
  [[ "$output" == *'export AGENT="codex"'* ]]
  [[ "$output" == *'# trailing note'* ]]
}


@test "_localrc_get_unmanaged_value ignores exports inside the managed block" {
  printf '%s\n' \
    'export EDITOR="vim"' \
    '' \
    "# >>> dotfiles localrc >>>" \
    'export EDITOR="hx"' \
    "# <<< dotfiles localrc <<<" > "$LOCALRC_PATH"

  run _localrc_get_unmanaged_value "EDITOR" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [ "$output" = "vim" ]
}

@test "_localrc_render_managed_block creates a fully-commented block in an empty file" {
  run _localrc_render_managed_block "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *"# >>> dotfiles localrc >>>"* ]]
  [[ "$output" == *"# ───── Editor and agent ─────"* ]]
  [[ "$output" == *"# Default: hx"* ]]
  [[ "$output" == *"# export EDITOR=\"hx\""* ]]
  [[ "$output" == *"# Default: code"* ]]
  [[ "$output" == *"# export E_EDITOR=\"code\""* ]]
  [[ "$output" == *"# ───── XDG base directories ─────"* ]]
  [[ "$output" == *"# ───── Homebrew skip lists ─────"* ]]
  [[ "$output" == *"# <<< dotfiles localrc <<<"* ]]
}

@test "_localrc_render_managed_block preserves user-uncommented exports" {
  printf '%s\n' \
    "# >>> dotfiles localrc >>>" \
    'export EDITOR="vim"' \
    "# <<< dotfiles localrc <<<" > "$LOCALRC_PATH"

  run _localrc_render_managed_block "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run _localrc_get_managed_value "EDITOR" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [ "$output" = "vim" ]

  run grep -c '^# export EDITOR=' "$LOCALRC_PATH"
  [ "$output" = "0" ]
}

@test "_localrc_render_managed_block is idempotent" {
  _localrc_render_managed_block "$LOCALRC_PATH"
  cp "$LOCALRC_PATH" "$BATS_TEST_TMPDIR/.localrc.first"
  _localrc_render_managed_block "$LOCALRC_PATH"

  run diff "$BATS_TEST_TMPDIR/.localrc.first" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
}

@test "_localrc_render_managed_block leaves content outside the block untouched" {
  printf '%s\n' \
    '# my secret' \
    'export TOKEN="abc"' > "$LOCALRC_PATH"

  run _localrc_render_managed_block "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [[ "$output" == *'# my secret'* ]]
  [[ "$output" == *'export TOKEN="abc"'* ]]
  [[ "$output" == *"# >>> dotfiles localrc >>>"* ]]
}

@test "_localrc_render_managed_block drops user-added lines inside the block" {
  printf '%s\n' \
    "# >>> dotfiles localrc >>>" \
    "# my custom comment" \
    'export NOT_IN_REGISTRY="x"' \
    'export EDITOR="vim"' \
    "# <<< dotfiles localrc <<<" > "$LOCALRC_PATH"

  run _localrc_render_managed_block "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run grep -c '^# my custom comment' "$LOCALRC_PATH"
  [ "$output" = "0" ]
  run grep -c '^export NOT_IN_REGISTRY' "$LOCALRC_PATH"
  [ "$output" = "0" ]
  run _localrc_get_managed_value "EDITOR" "$LOCALRC_PATH"
  [ "$output" = "vim" ]
}

@test "_localrc_set_managed_var produces a fully-rendered block" {
  run _localrc_set_managed_var "EDITOR" "nvim" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [[ "$output" == *"# Managed by script/localrc"* ]]
  [[ "$output" == *"# ───── Editor and agent ─────"* ]]
  [[ "$output" == *'export EDITOR="nvim"'* ]]
  [[ "$output" == *"# Default: hx"* ]]
  [[ "$output" == *"# export AGENT=\"claude\""* ]]
}

@test "_localrc_unset_managed_var reverts to commented default" {
  _localrc_set_managed_var "EDITOR" "nvim" "$LOCALRC_PATH"

  run _localrc_unset_managed_var "EDITOR" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run grep -c '^export EDITOR=' "$LOCALRC_PATH"
  [ "$output" = "0" ]
  run grep -c '^# export EDITOR=' "$LOCALRC_PATH"
  [ "$output" = "1" ]
}

@test "_localrc_unset_managed_var reverts to commented-empty for no-default var" {
  _localrc_set_managed_var "HOMEBREW_BUNDLE_CASK_SKIP" "slack" "$LOCALRC_PATH"

  run _localrc_unset_managed_var "HOMEBREW_BUNDLE_CASK_SKIP" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run grep -c '^export HOMEBREW_BUNDLE_CASK_SKIP=' "$LOCALRC_PATH"
  [ "$output" = "0" ]
  run grep -c '^# export HOMEBREW_BUNDLE_CASK_SKIP=' "$LOCALRC_PATH"
  [ "$output" = "1" ]
}
