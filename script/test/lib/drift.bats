#!/usr/bin/env bats

setup() {
  load '../test_helper'

  # Source dependencies first (drift.sh also sources them via guard)
  source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
  source "$DOTFILES_ROOT/script/lib/brewfile.sh"
  source "$DOTFILES_ROOT/script/lib/drift.sh"

  copy_fixture "Brewfile.full"

  # Default: no skip lists, no ignore file
  unset HOMEBREW_BUNDLE_CASK_SKIP
  unset HOMEBREW_BUNDLE_MAS_SKIP
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/nonexistent"
}

# --- _collect_drift_formulae ---

@test "_collect_drift_formulae returns untracked formulae" {
  # Mock brew leaves to return some tracked and some untracked
  brew() { echo "git"; echo "jq"; echo "unknown-formula"; }
  export -f brew
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ "$output" = "unknown-formula" ]
}

@test "_collect_drift_formulae returns empty when all tracked" {
  brew() { echo "git"; echo "jq"; }
  export -f brew
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_collect_drift_formulae returns empty when brew fails" {
  brew() { return 1; }
  export -f brew
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_collect_drift_formulae filters ignored packages" {
  brew() { echo "unknown-formula"; }
  export -f brew
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/ignore"
  echo "unknown-formula" > "$AUDIT_IGNORE_FILE"
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _collect_drift_casks ---

@test "_collect_drift_casks returns untracked casks" {
  brew() {
    case "$1" in
      list) echo "1password"; echo "firefox"; echo "unknown-cask" ;;
    esac
  }
  export -f brew
  run _collect_drift_casks
  [ "$status" -eq 0 ]
  [ "$output" = "unknown-cask" ]
}

@test "_collect_drift_casks filters skipped casks" {
  export HOMEBREW_BUNDLE_CASK_SKIP="unknown-cask"
  brew() {
    case "$1" in
      list) echo "unknown-cask" ;;
    esac
  }
  export -f brew
  run _collect_drift_casks
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _collect_drift_taps ---

@test "_collect_drift_taps returns untracked taps" {
  brew() {
    echo "homebrew/bundle"
    echo "homebrew/cask-fonts"
    echo "nikitabobko/tap"
    echo "some/unknown-tap"
  }
  export -f brew
  run _collect_drift_taps
  [ "$status" -eq 0 ]
  [ "$output" = "some/unknown-tap" ]
}

@test "_collect_drift_taps skips implicit taps" {
  brew() {
    echo "homebrew/core"
    echo "homebrew/cask"
    echo "homebrew/bundle"
  }
  export -f brew
  run _collect_drift_taps
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _collect_drift_mas ---

@test "_collect_drift_mas returns untracked mas apps" {
  mas() { echo "409183694 Keynote (14.0)"; echo "999999999 Unknown App (1.0)"; }
  export -f mas
  run _collect_drift_mas
  [ "$status" -eq 0 ]
  [ "$output" = "999999999 Unknown App" ]
}

@test "_collect_drift_mas filters Apple-native apps" {
  mas() { echo "682658836 GarageBand (10.4.11)"; echo "310633997 WhatsApp (26.12.78)"; }
  export -f mas
  mdfind() {
    case "$1" in
      *682658836*) echo "/Applications/GarageBand.app" ;;
      *310633997*) echo "/Applications/WhatsApp.app" ;;
    esac
  }
  export -f mdfind
  mdls() {
    case "$4" in
      */GarageBand.app) echo "com.apple.garageband10" ;;
      */WhatsApp.app)   echo "net.whatsapp.WhatsApp" ;;
    esac
  }
  export -f mdls
  run _collect_drift_mas
  [ "$status" -eq 0 ]
  [ "$output" = "310633997 WhatsApp" ]
}

@test "_collect_drift_mas filters skipped mas ids" {
  export HOMEBREW_BUNDLE_MAS_SKIP="999999999"
  mas() { echo "999999999 Unknown App (1.0)"; }
  export -f mas
  run _collect_drift_mas
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _count_total_drift ---

@test "_count_total_drift sums all drift categories" {
  brew() {
    case "$1" in
      leaves) echo "unknown-formula" ;;
      list)   echo "unknown-cask" ;;
      tap)    echo "homebrew/bundle" ;;
    esac
  }
  export -f brew
  mas() { return 1; }
  export -f mas
  run _count_total_drift
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}
