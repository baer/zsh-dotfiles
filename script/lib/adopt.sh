#!/usr/bin/env bash
#
# adopt.sh — cask adoption primitives
#
# Source this file; do not execute it directly.
# Depends on: lib/term.sh, lib/log.sh, lib/spinner.sh, lib/brewfile.sh
# Requires LOGFILE and BREWFILE to be set by the caller.
# Provides _app_is_running, _prompt_quit_app, _trash_app,
#          _remove_from_skip_list, _adopt_cask.

# Source guard
[[ -n "${_ADOPT_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_ADOPT_SH_LOADED=1

# Source dependencies
_ADOPT_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=term.sh
source "$_ADOPT_SH_DIR/term.sh"
# shellcheck source=log.sh
source "$_ADOPT_SH_DIR/log.sh"
# shellcheck source=spinner.sh
source "$_ADOPT_SH_DIR/spinner.sh"
# shellcheck source=brewfile.sh
source "$_ADOPT_SH_DIR/brewfile.sh"

# ---------------------------------------------------------------------------
# Primitives
# ---------------------------------------------------------------------------

# Check if an app is currently running.
# Args: app_base_name (e.g. "Slack" not "Slack.app")
# Returns 0 if running, 1 if not.
_app_is_running() {
  local app_base="$1"
  # Match the .app/ bundle path to avoid false positives from system
  # processes (e.g. "Cursor" matching macOS's "CursorUIViewService").
  pgrep -fi "$app_base\.app/" > /dev/null 2>&1
}

# Gracefully quit a running app, escalating from AppleScript to SIGTERM.
# Returns 0 if the app is no longer running, 1 if user skipped or quit failed.
_prompt_quit_app() {
  local app_base="$1"

  # Try graceful AppleScript quit first
  log_warn "$app_base is running. Attempting to quit…"
  osascript -e "quit app \"$app_base\"" 2>/dev/null

  # Wait up to 5 seconds for the app to exit
  local waited=0
  while (( waited < 5 )) && _app_is_running "$app_base"; do
    sleep 1
    (( waited++ ))
  done

  if ! _app_is_running "$app_base"; then
    return 0
  fi

  # AppleScript quit didn't work — ask user
  log_warn "$app_base is still running after quit signal."
  printf "    Press Enter to force-quit, or 's' to skip... "
  local response
  read -r response
  if [[ "$response" == "s" ]]; then
    return 1
  fi

  # Force-quit via SIGTERM
  pkill -fi "$app_base\.app/" 2>/dev/null
  sleep 2

  if _app_is_running "$app_base"; then
    log_error "$app_base is still running — skipping"
    return 1
  fi
  return 0
}

# Move an .app bundle to Trash using the Finder API (handles SIP/permissions).
# Falls back to mv if AppleScript fails (e.g. headless session).
# Returns 0 on success (or if path doesn't exist), 1 on failure.
_trash_app() {
  local app_path="$1"
  [[ -d "$app_path" ]] || return 0  # nothing to trash

  # Finder API respects macOS permissions and shows auth dialogs when needed
  if osascript -e "tell application \"Finder\" to delete POSIX file \"$app_path\"" >/dev/null 2>&1; then
    return 0
  fi

  # Fallback: direct mv (works for user-owned apps without SIP)
  if mv "$app_path" "$HOME/.Trash/" 2>/dev/null; then
    return 0
  fi

  log_error "Could not move $(basename "$app_path") to Trash (permissions?)"
  return 1
}

# ---------------------------------------------------------------------------
# Skip list management
# ---------------------------------------------------------------------------

# Remove a cask from HOMEBREW_BUNDLE_CASK_SKIP in ~/.localrc.
_remove_from_skip_list() {
  local cask="$1"
  local localrc="$HOME/.localrc"

  [[ -z "${HOMEBREW_BUNDLE_CASK_SKIP:-}" ]] && return 0

  # Remove the cask from the space-separated list
  local new_skip
  new_skip="$(echo "$HOMEBREW_BUNDLE_CASK_SKIP" | tr ' ' '\n' | grep -vx "$cask" | tr '\n' ' ' | sed 's/ $//')"

  if [[ -f "$localrc" ]] && grep -q "HOMEBREW_BUNDLE_CASK_SKIP" "$localrc"; then
    if [[ -z "$new_skip" ]]; then
      # Remove the line entirely
      sed -i '' '/^export HOMEBREW_BUNDLE_CASK_SKIP=/d' "$localrc"
    else
      sed -i '' "s|^export HOMEBREW_BUNDLE_CASK_SKIP=.*|export HOMEBREW_BUNDLE_CASK_SKIP=\"$new_skip\"|" "$localrc"
    fi
  fi

  export HOMEBREW_BUNDLE_CASK_SKIP="$new_skip"
}

# ---------------------------------------------------------------------------
# Full adoption flow
# ---------------------------------------------------------------------------

# Warm the sudo timestamp before running `brew --adopt` behind a spinner.
# Homebrew may need sudo to fix app permissions during adoption.
_prewarm_adopt_sudo() {
  sudo -n true >/dev/null 2>&1 && return 0

  log_info "Adopting $1 may require your macOS password."
  sudo -v
}

# Adopt a manually installed app into brew management.
# Trashes the manual copy, runs brew install, updates Brewfile and skip list.
# Requires LOGFILE and BREWFILE to be set by the caller.
# Args: cask_name app_name
_adopt_cask() {
  local cask="$1" app_name="$2"
  local app_path="/Applications/$app_name"
  local app_base="${app_name%.app}"

  # Fast path: --adopt claims existing artifacts without trash/reinstall
  local adopt_output adopt_rc
  if _prewarm_adopt_sudo "$app_name" >> "$LOGFILE" 2>&1; then
    spinner_start "brew install --cask --adopt $cask"
    adopt_output="$(brew install --cask --adopt "$cask" 2>&1)"
    adopt_rc=$?
    echo "$adopt_output" >> "$LOGFILE"
  else
    adopt_output="sudo preflight failed before brew install --cask --adopt $cask"
    adopt_rc=1
    echo "$adopt_output" >> "$LOGFILE"
  fi
  if (( adopt_rc == 0 )); then
    spinner_stop ok "brew install --cask --adopt $cask"
  else
    spinner_stop warn "brew install --cask --adopt $cask (falling back to reinstall)"
    # Surface the brew error so the user isn't left guessing
    local adopt_reason
    adopt_reason="$(echo "$adopt_output" | grep -iE 'error|conflict|mismatch|already|exists|failed' | tail -1)"
    [[ -n "$adopt_reason" ]] && log_warn "$adopt_reason"

    # Fallback: trash + clean install (version mismatch, etc.)
    if _app_is_running "$app_base"; then
      _prompt_quit_app "$app_base" || { log_info "Skipped $cask"; return 1; }
    fi

    if ! _trash_app "$app_path"; then
      log_info "Skipping adoption of $cask"
      return 1
    fi

    # The manual app is gone — remove from skip list now so brew bundle
    # can recover this cask if the install below fails.
    _remove_from_skip_list "$cask"

    # Ensure cask is in Brewfile before install attempt (same recovery reason)
    if ! grep -qx "cask '$cask'" "$BREWFILE"; then
      _brewfile_insert "cask" "$cask"
    fi

    spinner_start "brew install --cask $cask"
    if brew install --cask "$cask" >> "$LOGFILE" 2>&1; then
      spinner_stop ok "brew install --cask $cask"
    else
      spinner_stop fail "brew install --cask $cask (see ${LOGFILE##*/} for details)"
      return 1
    fi
  fi

  # Update Brewfile if not already listed (fast-path --adopt doesn't go above)
  if ! grep -qx "cask '$cask'" "$BREWFILE"; then
    _brewfile_insert "cask" "$cask"
  fi

  # Remove from skip list if present (fast-path --adopt doesn't go above)
  _remove_from_skip_list "$cask"

  return 0
}
