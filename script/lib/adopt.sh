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
  pgrep -fi "$app_base" > /dev/null 2>&1
}

# Prompt the user to quit a running app.
# Warns, waits for input, re-checks the process.
# Returns 0 if safe to proceed, 1 if user skipped or app still running.
_prompt_quit_app() {
  local app_base="$1"
  log_warn "$app_base is running. Please quit it before continuing."
  printf "    Press Enter when ready, or 's' to skip... "
  local response
  read -r response
  if [[ "$response" == "s" ]]; then
    return 1
  fi
  # Re-check after user claims they quit
  if _app_is_running "$app_base"; then
    log_error "$app_base is still running — skipping"
    return 1
  fi
  return 0
}

# Move an .app bundle to Trash.
# Returns 0 on success (or if path doesn't exist), 1 on failure.
_trash_app() {
  local app_path="$1"
  [[ -d "$app_path" ]] || return 0  # nothing to trash
  if mv "$app_path" "$HOME/.Trash/" 2>/dev/null; then
    return 0
  else
    log_error "Could not move $(basename "$app_path") to Trash (permissions?)"
    return 1
  fi
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

# Adopt a manually installed app into brew management.
# Trashes the manual copy, runs brew install, updates Brewfile and skip list.
# Requires LOGFILE and BREWFILE to be set by the caller.
# Args: cask_name app_name
_adopt_cask() {
  local cask="$1" app_name="$2"
  local app_path="/Applications/$app_name"
  local app_base="${app_name%.app}"

  # Fast path: --adopt claims existing artifacts without trash/reinstall
  spinner_start "brew install --cask --adopt $cask"
  if brew install --cask --adopt "$cask" >> "$LOGFILE" 2>&1; then
    spinner_stop ok "brew install --cask --adopt $cask"
  else
    spinner_stop warn "brew install --cask --adopt $cask (falling back to reinstall)"

    # Fallback: trash + clean install (version mismatch, etc.)
    if _app_is_running "$app_base"; then
      _prompt_quit_app "$app_base" || { log_info "Skipped $cask"; return 1; }
    fi

    if ! _trash_app "$app_path"; then
      log_info "Skipping adoption of $cask"
      return 1
    fi

    spinner_start "brew install --cask $cask"
    if brew install --cask "$cask" >> "$LOGFILE" 2>&1; then
      spinner_stop ok "brew install --cask $cask"
    else
      spinner_stop fail "brew install --cask $cask (see ${LOGFILE##*/} for details)"
      return 1
    fi
  fi

  # Update Brewfile if not already listed
  if ! grep -qx "cask '$cask'" "$BREWFILE"; then
    _brewfile_insert "cask" "$cask"
  fi

  # Remove from skip list if present
  _remove_from_skip_list "$cask"

  return 0
}
