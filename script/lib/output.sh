#!/usr/bin/env bash
#
# output.sh — shared output library for dotfiles scripts
#
# Source this file; do not execute it directly.
# Provides colored status output, spinners, and prompts.
# Respects $NO_COLOR (https://no-color.org) and detects TTY.

# ---------------------------------------------------------------------------
# Terminal capability detection
# ---------------------------------------------------------------------------

_is_tty() { [[ -t 1 ]]; }

_should_color() {
  [[ -z "${NO_COLOR:-}" ]] && _is_tty && [[ "${TERM:-dumb}" != "dumb" ]]
}

if [[ -z "${INTERACTIVE:-}" ]]; then
  if [[ -t 0 ]] && [[ -z "${CI:-}" ]]; then
    INTERACTIVE=true
  else
    INTERACTIVE=false
  fi
  export INTERACTIVE
fi

# ---------------------------------------------------------------------------
# Color / symbol setup
# ---------------------------------------------------------------------------

if _should_color; then
  _RST=$'\e[0m'
  _BOLD=$'\e[1m'
  _DIM=$'\e[2m'
  _RED=$'\e[31m'
  _GREEN=$'\e[32m'
  _YELLOW=$'\e[33m'
  _BLUE=$'\e[34m'
  _CYAN=$'\e[36m'
else
  _RST="" _BOLD="" _DIM="" _RED="" _GREEN="" _YELLOW="" _BLUE="" _CYAN=""
fi

_CHECK="${_GREEN}✓${_RST}"
_CROSS="${_RED}✗${_RST}"
_WARN="${_YELLOW}⚠${_RST}"
_SKIP="${_DIM}-${_RST}"
_INFO="${_DIM}·${_RST}"

# ---------------------------------------------------------------------------
# Status output
# ---------------------------------------------------------------------------

log_success() { printf "  %s %s\n" "$_CHECK" "$1"; }
log_error()   { printf "  %s %s\n" "$_CROSS" "$1" >&2; }
log_warn()    { printf "  %s %s\n" "$_WARN"  "$1"; }
log_skip()    { printf "  %s %s\n" "$_SKIP"  "${_DIM}$1${_RST}"; }
log_info()    { printf "  %s %s\n" "$_INFO"  "${_DIM}$1${_RST}"; }

log_phase() {
  local number="$1" name="$2"
  printf "\n  ${_BOLD}${_CYAN}[%s]${_RST} ${_BOLD}%s${_RST}\n\n" "$number" "$name"
}

# ---------------------------------------------------------------------------
# Spinner
# ---------------------------------------------------------------------------

_SPINNER_PID=""
_SPINNER_FRAMES=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )

spinner_start() {
  local message="$1"

  # Non-interactive: just print the message, no animation
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "  · %s\n" "$message"
    return
  fi

  (
    trap 'exit 0' TERM
    local i=0
    while true; do
      printf "\r\e[2K  ${_CYAN}%s${_RST} %s" "${_SPINNER_FRAMES[$((i % ${#_SPINNER_FRAMES[@]}))]}" "$message"
      i=$((i + 1))
      sleep 0.08
    done
  ) &
  _SPINNER_PID=$!
}

spinner_stop() {
  local status="$1" message="$2"

  if [[ -n "$_SPINNER_PID" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\e[2K"
  fi

  case "$status" in
    ok)   log_success "$message" ;;
    fail) log_error   "$message" ;;
    warn) log_warn    "$message" ;;
    skip) log_skip    "$message" ;;
  esac
}

# Kill spinner on unexpected exit (sourced into caller's trap chain)
_spinner_cleanup() {
  if [[ -n "${_SPINNER_PID:-}" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\e[2K"
  fi
}

# ---------------------------------------------------------------------------
# Run a command with a spinner, capturing output to a log file
# ---------------------------------------------------------------------------

run_with_spinner() {
  local message="$1" logfile="$2"
  shift 2

  spinner_start "$message"
  if "$@" >> "$logfile" 2>&1; then
    spinner_stop ok "$message"
    return 0
  else
    local rc=$?
    spinner_stop fail "$message (see ${logfile##*/} for details)"
    return "$rc"
  fi
}

# ---------------------------------------------------------------------------
# Prompts
# ---------------------------------------------------------------------------

prompt_user() {
  local question="$1" default="${2:-}"
  local display_default=""

  if [[ -n "$default" ]]; then
    display_default=" ${_DIM}($default)${_RST}"
  fi

  printf "  ${_YELLOW}?${_RST} %s%s " "$question" "$display_default" >&2
  local answer
  read -r answer
  printf "%s" "${answer:-$default}"
}
