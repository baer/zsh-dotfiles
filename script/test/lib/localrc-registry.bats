#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/localrc-registry.sh"
}

@test "_localrc_registry_groups returns ordered group ids" {
  run _localrc_registry_groups
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "editor" ]
  [ "${lines[1]}" = "xdg" ]
  [ "${lines[2]}" = "homebrew" ]
}

@test "_localrc_registry_group_label returns human label" {
  run _localrc_registry_group_label "editor"
  [ "$status" -eq 0 ]
  [ "$output" = "Editor and agent" ]
}

@test "_localrc_registry_vars_in returns vars for a group in order" {
  run _localrc_registry_vars_in "xdg"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "XDG_CONFIG_HOME" ]
  [ "${lines[3]}" = "XDG_STATE_HOME" ]
}

@test "_localrc_registry_default returns the default value" {
  run _localrc_registry_default "EDITOR"
  [ "$status" -eq 0 ]
  [ "$output" = "code" ]
}

@test "_localrc_registry_default returns empty for vars without a default" {
  run _localrc_registry_default "HOMEBREW_BUNDLE_CASK_SKIP"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_localrc_registry_description returns a one-line description" {
  run _localrc_registry_description "AGENT"
  [ "$status" -eq 0 ]
  [ "$output" = "Agent CLI launched by bin/a" ]
}

@test "_localrc_registry_all_vars enumerates every var across groups" {
  run _localrc_registry_all_vars
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 8 ]
}
