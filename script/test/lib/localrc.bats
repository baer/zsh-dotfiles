#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/localrc.sh"
  export LOCALRC_PATH="$BATS_TEST_TMPDIR/.localrc"
}

@test "_localrc_set_managed_var creates a managed block in an empty file" {
  run _localrc_set_managed_var "EDITOR" "nvim" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "# >>> dotfiles localrc >>>" ]
  [ "${lines[1]}" = 'export EDITOR="nvim"' ]
  [ "${lines[2]}" = "# <<< dotfiles localrc <<<" ]
}

@test "_localrc_set_managed_var replaces an existing managed value" {
  printf '%s\n' \
    "# >>> dotfiles localrc >>>" \
    'export EDITOR="code"' \
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
    'export EDITOR="code"' \
    "# <<< dotfiles localrc <<<" \
    '' \
    '# trailing note' > "$LOCALRC_PATH"

  run _localrc_set_managed_var "AGENT" "codex" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [[ "$output" == *'# user secret'* ]]
  [[ "$output" == *'export TOKEN="abc123"'* ]]
  [[ "$output" == *'export EDITOR="code"'* ]]
  [[ "$output" == *'export AGENT="codex"'* ]]
  [[ "$output" == *'# trailing note'* ]]
}

@test "_localrc_unset_managed_var removes the block when it becomes empty" {
  printf '%s\n' \
    "# >>> dotfiles localrc >>>" \
    'export HOMEBREW_BUNDLE_CASK_SKIP="slack"' \
    "# <<< dotfiles localrc <<<" > "$LOCALRC_PATH"

  run _localrc_unset_managed_var "HOMEBREW_BUNDLE_CASK_SKIP" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]

  run cat "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_localrc_get_unmanaged_value ignores exports inside the managed block" {
  printf '%s\n' \
    'export EDITOR="helix"' \
    '' \
    "# >>> dotfiles localrc >>>" \
    'export EDITOR="nvim"' \
    "# <<< dotfiles localrc <<<" > "$LOCALRC_PATH"

  run _localrc_get_unmanaged_value "EDITOR" "$LOCALRC_PATH"
  [ "$status" -eq 0 ]
  [ "$output" = "helix" ]
}
