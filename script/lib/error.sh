#!/usr/bin/env bash
#
# error.sh — error context display with pattern-matched hints
#
# Source this file; do not execute it directly.
# Depends on: lib/term.sh, lib/log.sh

# Source guard
[[ -n "${_ERROR_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_ERROR_SH_LOADED=1

# Source dependencies
_ERROR_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=term.sh
source "$_ERROR_SH_DIR/term.sh"
# shellcheck source=log.sh
source "$_ERROR_SH_DIR/log.sh"

# ---------------------------------------------------------------------------
# Error context with hints
# ---------------------------------------------------------------------------

log_error_context() {
  local logfile="$1" phase="${2:-}"
  local tail_lines=20

  if [[ -n "$phase" ]]; then
    log_error "Failed during: $phase"
  fi

  if [[ ! -f "$logfile" ]] || [[ ! -s "$logfile" ]]; then
    return
  fi

  local logname="${logfile##*/}"

  # Surface high-signal error lines from anywhere in the log — the relevant
  # error often scrolls past the 20-line tail (e.g. npm error mid-log,
  # followed by trailing "complete!" lines from a later step).
  local highlights
  highlights="$(grep -E '^(npm error|mise ERROR|Error:|error:|fatal:|✗ )' "$logfile" 2>/dev/null \
    | grep -v 'A complete log of this run' \
    | tail -n 5 || true)"

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    # Size to terminal: min 80, max terminal width minus indent
    local term_w
    term_w="$(tput cols 2>/dev/null || printf '%s' "${COLUMNS:-80}")"
    local w=$((term_w - 4))  # 2-space indent + small margin
    [[ $w -lt 78 ]] && w=78

    if [[ -n "$highlights" ]]; then
      printf "\n  ${_BOLD}Errors found:${_RST}\n"
      while IFS= read -r line; do
        printf "    ${_RED}%s${_RST}\n" "$line"
      done <<< "$highlights"
    fi

    local header_content="─ ${logname} (last ${tail_lines} lines) "
    local header_len=${#header_content}
    local remaining=$((w - header_len - 1))
    local header_pad=""
    local i; for ((i=0; i<remaining; i++)); do header_pad+="$_BOX_H"; done

    printf "\n  %s%s%s%s\n" "$_BOX_TL" "$_BOX_H" "${_DIM}${header_content}${_RST}" "${header_pad}${_BOX_TR}"

    while IFS= read -r line; do
      _draw_box_row $w "  ${_DIM}${line}${_RST}"
    done < <(tail -n "$tail_lines" "$logfile")

    _draw_box_bottom $w

    printf "  ${_DIM}Full log: %s${_RST}\n" "$logfile"
  else
    if [[ -n "$highlights" ]]; then
      printf "\n  Errors found:\n"
      while IFS= read -r line; do
        printf "    %s\n" "$line"
      done <<< "$highlights"
    fi
    printf "\n  Last %d lines of %s:\n" "$tail_lines" "$logname"
    tail -n "$tail_lines" "$logfile" | while IFS= read -r line; do
      printf "    %s\n" "$line"
    done
  fi

  # Detect common error patterns and suggest fixes
  local log_tail
  log_tail="$(tail -n 20 "$logfile" 2>/dev/null || true)"
  local hint=""
  hint="$(_detect_error_hint "$log_tail")"

  if [[ -n "$hint" ]]; then
    printf "\n  ${_YELLOW}hint:${_RST} %s\n" "$hint"
  fi
}

_detect_error_hint() {
  local text="$1"

  if [[ "$text" == *"xcode-select"* ]] || [[ "$text" == *"xcrun: error"* ]]; then
    printf "Xcode CLI tools may need installing or updating.\n        Run: xcode-select --install"
    return
  fi

  if [[ "$text" == *"Permission denied"* ]] && [[ "$text" == *"/usr/local"* ]]; then
    printf "Homebrew directory permissions issue.\n        Run: sudo chown -R \$(whoami) /usr/local/*"
    return
  fi

  if [[ "$text" == *"curl: (60)"* ]] || [[ "$text" == *"SSL certificate"* ]]; then
    printf "SSL/network error. Check your internet connection and proxy settings."
    return
  fi

  if [[ "$text" == *"is unavailable"* ]] || [[ "$text" == *"was renamed"* ]]; then
    printf "A cask may have been removed or renamed in Homebrew.\n        Remove it from Brewfile and re-run."
    return
  fi

  if [[ "$text" == *"Could not resolve host"* ]] || [[ "$text" == *"Network is unreachable"* ]]; then
    printf "Network connectivity issue. Check your internet connection."
    return
  fi

  if [[ "$text" == *"EEXIST"* ]] && [[ "$text" == *"npm"* ]]; then
    printf "npm found conflicting files from a previous install.\n        Run the command shown above with --force, or remove the conflicting file."
    return
  fi

  if [[ "$text" == *"sharp: Attempting to build from source"* ]] \
     || ( [[ "$text" == *"node-gyp"* ]] && [[ "$text" == *"npm error"* ]] ); then
    printf "A native npm module fell back to source build (often a flaky prebuild download).\n        Re-run bootstrap; if it persists, pin the affected tool to a stable version in mise/config.toml."
    return
  fi

  if [[ "$text" == *"lockf:"* ]] && [[ "$text" == *"already locked"* ]]; then
    printf "Homebrew update lock is held by another process.\n        Run: lsof \"\$(brew --prefix)/var/homebrew/locks/update\" to find the holder."
    return
  fi

  if [[ "$text" == *"Another"*"brew update"*"already running"* ]]; then
    printf "Homebrew update lock is held by another process.\n        Run: lsof \"\$(brew --prefix)/var/homebrew/locks/update\" to find the holder."
    return
  fi

  if [[ "$text" == *"does not exist"* ]] && [[ "$text" == *"brew untap"* ]]; then
    printf "An obsolete tap is blocking brew update.\n        The error message above includes the untap command to fix it."
    return
  fi

  if [[ "$text" == *"has been disabled because"* ]]; then
    printf "A disabled formula is causing errors during upgrade.\n        Uninstall it: brew uninstall <formula>"
    return
  fi

  if [[ "$text" == *"It seems the App source"* ]] && [[ "$text" == *"is not there"* ]]; then
    printf "A cask has metadata but its app is missing.\n        Reinstall: brew reinstall --cask <cask> or uninstall: brew uninstall --cask <cask>"
    return
  fi
}
