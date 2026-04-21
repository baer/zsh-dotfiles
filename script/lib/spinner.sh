#!/usr/bin/env bash
#
# spinner.sh — spinner and substep animation
#
# Source this file; do not execute it directly.
# Depends on: lib/term.sh

# Source guard
[[ -n "${_SPINNER_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_SPINNER_SH_LOADED=1

# Source dependencies
_SPINNER_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=term.sh
source "$_SPINNER_SH_DIR/term.sh"

# ---------------------------------------------------------------------------
# Spinner state
# ---------------------------------------------------------------------------

_SPINNER_PID=""
_SPINNER_FRAMES=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
_SPINNER_STATUS_FILE=""

# ---------------------------------------------------------------------------
# Substep state
# ---------------------------------------------------------------------------

_SUBSTEP_COUNT=0
_SUBSTEP_CURSOR_DIRTY=0

# ---------------------------------------------------------------------------
# Internal: parameterized spinner start/stop
# ---------------------------------------------------------------------------

# _spinner_start_impl message indent
# Starts a background spinner animation with the given indent prefix.
_spinner_start_impl() {
  local message="$1" indent="$2"

  # Non-interactive: just print the message, no animation
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "%s· %s\n" "$indent" "$message"
    return
  fi

  _SPINNER_STATUS_FILE="$(mktemp "${TMPDIR:-/tmp}/.dotfiles_spinner.XXXXXX")"

  (
    trap 'exit 0' TERM
    local i=0
    while true; do
      local extra=""
      if [[ -f "$_SPINNER_STATUS_FILE" ]] && [[ -s "$_SPINNER_STATUS_FILE" ]]; then
        extra=" ${_DIM}· $(cat "$_SPINNER_STATUS_FILE")${_RST}"
      fi
      printf "\r\e[2K%s${_CYAN}%s${_RST} %s%s" "$indent" "${_SPINNER_FRAMES[$((i % ${#_SPINNER_FRAMES[@]}))]}" "$message" "$extra"
      i=$((i + 1))
      sleep 0.08
    done
  ) &
  _SPINNER_PID=$!
}

# _spinner_stop_impl status message indent
# Kills the background spinner and prints a status line.
_spinner_stop_impl() {
  local status="$1" message="$2" indent="$3"

  if [[ -n "$_SPINNER_PID" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\e[2K"
  fi

  if [[ -n "$_SPINNER_STATUS_FILE" ]]; then
    rm -f "$_SPINNER_STATUS_FILE"
    _SPINNER_STATUS_FILE=""
  fi

  local sym
  sym="$(_status_sym "$status")"
  if [[ "$status" == "fail" ]]; then
    printf "%s%s %s\n" "$indent" "$sym" "$message" >&2
  elif [[ "$status" == "skip" ]]; then
    printf "%s%s %s\n" "$indent" "$sym" "${_DIM}$message${_RST}"
  else
    printf "%s%s %s\n" "$indent" "$sym" "$message"
  fi
}

# Kill spinner on unexpected exit (sourced into caller's trap chain)
_spinner_cleanup() {
  if [[ -n "${_SPINNER_PID:-}" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\e[2K"
  fi
  if [[ -n "${_SPINNER_STATUS_FILE:-}" ]]; then
    rm -f "$_SPINNER_STATUS_FILE"
    _SPINNER_STATUS_FILE=""
  fi
}

# ---------------------------------------------------------------------------
# Public spinner API (2-space indent)
# ---------------------------------------------------------------------------

spinner_start() { _spinner_start_impl "$1" "  "; }
spinner_stop()  { _spinner_stop_impl "$1" "$2" "  "; }

# ---------------------------------------------------------------------------
# Sub-step output (6-space indent, beneath a phase header)
# ---------------------------------------------------------------------------

substep_log_success() { printf "      %s %s\n" "$_CHECK" "$1"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_error()   { printf "      %s %s\n" "$_CROSS" "$1" >&2; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_warn()    { printf "      %s %s\n" "$_WARN"  "$1"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_info()    { printf "      %s %s\n" "$_INFO"  "${_DIM}$1${_RST}"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }

# Mark the substep cursor as dirty — call this when untracked lines are
# printed between phase_end_deferred and phase_resolve (e.g. interactive
# prompts). phase_resolve will skip cursor rewrite and print at current
# position instead.
substep_mark_dirty() { _SUBSTEP_CURSOR_DIRTY=1; }

substep_start() {
  _spinner_start_impl "$1" "      "
  # Non-interactive path: count the substep (matches original substep_start behavior)
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1))
  fi
}

substep_stop() {
  _spinner_stop_impl "$1" "$2" "      "
  _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1))
}

# ---------------------------------------------------------------------------
# Substep runners
# ---------------------------------------------------------------------------

run_with_substep_spinner() {
  local message="$1" logfile="$2"
  shift 2

  substep_start "$message"
  if "$@" >> "$logfile" 2>&1; then
    substep_stop ok "$message"
    return 0
  else
    local rc=$?
    substep_stop fail "$message (see ${logfile##*/} for details)"
    return "$rc"
  fi
}

run_with_substep_streaming_spinner() {
  local message="$1" logfile="$2"
  shift 2

  substep_start "$message"

  local exit_code_file
  exit_code_file="$(mktemp "${TMPDIR:-/tmp}/.dotfiles_exit.XXXXXX")"

  {
    "$@" 2>&1 || echo $? > "$exit_code_file"
  } | while IFS= read -r line; do
    printf '%s\n' "$line" >> "$logfile"
    if [[ "$line" =~ ^(Installing|Upgrading|Using)[[:space:]]+(.+)$ ]]; then
      local pkg="${BASH_REMATCH[2]}"
      pkg="${pkg%%[[:space:]]*}"
      if [[ -n "$_SPINNER_STATUS_FILE" ]]; then
        printf '%s' "${BASH_REMATCH[1],,} ${pkg}" > "$_SPINNER_STATUS_FILE"
      fi
    fi
  done

  local rc=0
  if [[ -f "$exit_code_file" ]] && [[ -s "$exit_code_file" ]]; then
    rc="$(cat "$exit_code_file")"
  fi
  rm -f "$exit_code_file"

  if [[ $rc -eq 0 ]]; then
    substep_stop ok "$message"
  else
    substep_stop fail "$message (see ${logfile##*/} for details)"
  fi
  return "$rc"
}
