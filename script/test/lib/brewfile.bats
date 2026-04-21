#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/brewfile.sh"
}

# --- _brewfile_list_section ---

@test "_brewfile_list_section tap lists tap names" {
  copy_fixture "Brewfile.full"
  run _brewfile_list_section "tap"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "homebrew/bundle" ]
  [ "${lines[1]}" = "homebrew/cask-fonts" ]
  [ "${lines[2]}" = "nikitabobko/tap" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "_brewfile_list_section brew lists formula names" {
  copy_fixture "Brewfile.basic"
  run _brewfile_list_section "brew"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "git" ]
  [ "${lines[1]}" = "jq" ]
  [ "${lines[2]}" = "wget" ]
}

@test "_brewfile_list_section cask lists cask names" {
  copy_fixture "Brewfile.basic"
  run _brewfile_list_section "cask"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1password" ]
  [ "${lines[1]}" = "firefox" ]
  [ "${lines[2]}" = "google-chrome" ]
}

@test "_brewfile_list_section mas lists mas names" {
  copy_fixture "Brewfile.full"
  run _brewfile_list_section "mas"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Keynote" ]
  [ "${lines[1]}" = "Numbers" ]
  [ "${lines[2]}" = "Pages" ]
  [ "${lines[3]}" = "Xcode" ]
}

@test "_brewfile_list_section returns empty for missing section" {
  copy_fixture "Brewfile.basic"
  run _brewfile_list_section "mas"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

@test "_brewfile_list_section returns empty for empty file" {
  copy_fixture "Brewfile.empty"
  run _brewfile_list_section "brew"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

# --- _brewfile_contains ---

@test "_brewfile_contains finds existing formula" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "brew" "git"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains rejects missing formula" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "brew" "curl"
  [ "$status" -eq 1 ]
}

@test "_brewfile_contains finds existing cask" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "cask" "firefox"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains rejects missing cask" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "cask" "slack"
  [ "$status" -eq 1 ]
}

@test "_brewfile_contains finds existing tap" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "tap" "homebrew/bundle"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains finds mas entry by id" {
  copy_fixture "Brewfile.full"
  run _brewfile_contains "mas" "409183694"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains rejects missing mas id" {
  copy_fixture "Brewfile.full"
  run _brewfile_contains "mas" "999999999"
  [ "$status" -eq 1 ]
}

# --- _brewfile_insert ---

@test "_brewfile_insert adds formula in sorted position (middle)" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "brew" "fzf"
  run grep "^brew " "$BREWFILE"
  [ "${lines[0]}" = "brew 'fzf'" ]
  [ "${lines[1]}" = "brew 'git'" ]
  [ "${lines[2]}" = "brew 'jq'" ]
  [ "${lines[3]}" = "brew 'wget'" ]
}

@test "_brewfile_insert adds formula in sorted position (beginning)" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "brew" "ack"
  run grep "^brew " "$BREWFILE"
  [ "${lines[0]}" = "brew 'ack'" ]
  [ "${lines[1]}" = "brew 'git'" ]
}

@test "_brewfile_insert adds formula in sorted position (end)" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "brew" "zsh"
  run grep "^brew " "$BREWFILE"
  [ "${lines[3]}" = "brew 'zsh'" ]
}

@test "_brewfile_insert adds cask in sorted position" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "cask" "docker"
  run grep "^cask " "$BREWFILE"
  [ "${lines[0]}" = "cask '1password'" ]
  [ "${lines[1]}" = "cask 'docker'" ]
  [ "${lines[2]}" = "cask 'firefox'" ]
  [ "${lines[3]}" = "cask 'google-chrome'" ]
}

@test "_brewfile_insert adds mas entry with id in sorted position" {
  copy_fixture "Brewfile.full"
  _brewfile_insert "mas" "GarageBand" "682658836"
  run grep "^mas " "$BREWFILE"
  [ "${lines[0]}" = "mas 'GarageBand', id: 682658836" ]
  [ "${lines[1]}" = "mas 'Keynote', id: 409183694" ]
}

@test "_brewfile_insert creates new section when missing" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "mas" "Keynote" "409183694"
  # Should have a blank line before the new section
  run grep -c "^mas " "$BREWFILE"
  [ "$output" = "1" ]
  run grep "^mas " "$BREWFILE"
  [ "${lines[0]}" = "mas 'Keynote', id: 409183694" ]
}
