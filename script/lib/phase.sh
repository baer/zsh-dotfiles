#!/usr/bin/env bash
#
# phase.sh — phase lifecycle, column formatting, and summary box
#
# Source this file; do not execute it directly.
# Depends on: lib/term.sh, lib/spinner.sh, lib/log.sh

# Source guard
[[ -n "${_PHASE_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_PHASE_SH_LOADED=1

# Source dependencies
_PHASE_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=term.sh
source "$_PHASE_SH_DIR/term.sh"
# shellcheck source=spinner.sh
source "$_PHASE_SH_DIR/spinner.sh"
# shellcheck source=log.sh
source "$_PHASE_SH_DIR/log.sh"

# ---------------------------------------------------------------------------
# Column formatting (shared by phase_end and log_summary_box)
# ---------------------------------------------------------------------------

# Column widths for status rows
_COL_LABEL=20
_COL_DETAIL=28
_COL_TIMING=5

# _pad_to_width width string
# Like printf '%-Ns' but pads by visible character count, not byte count.
# This matters for multi-byte UTF-8 characters (e.g. ✓) and ANSI escapes.
_pad_to_width() {
  local target_w="$1" str="$2"
  local stripped
  stripped="$(printf '%s' "$str" | sed $'s/\e\\[[0-9;]*m//g')"
  local visible_len=${#stripped}
  local pad=$((target_w - visible_len))
  if [[ $pad -gt 0 ]]; then
    printf '%s%*s' "$str" "$pad" ""
  else
    printf '%s' "$str"
  fi
}

# _format_status_row sym label detail timing
# Returns the formatted string (no trailing newline).
_format_status_row() {
  local sym="$1" label="$2" detail="$3" timing="$4"
  local label_padded detail_padded timing_padded
  label_padded="$(_pad_to_width "$_COL_LABEL" "$label")"
  if [[ ${#detail} -gt $_COL_DETAIL ]]; then
    detail="${detail:0:$((_COL_DETAIL - 1))}…"
  fi
  detail_padded="$(_pad_to_width "$_COL_DETAIL" "$detail")"
  timing_padded="$(printf '%*s' "$_COL_TIMING" "$timing")"
  printf '%s' "  ${sym} ${label_padded}${_DIM}${detail_padded} ${timing_padded}${_RST}"
}

# ---------------------------------------------------------------------------
# Phase lifecycle (spinner-to-checkmark)
# ---------------------------------------------------------------------------

declare -A _PHASE_START_TIMES=()
_PHASE_TOTAL=4
_PHASE_CURRENT=0
_ACTIVE_PHASE_NAME=""
_ACTIVE_PHASE_NUMBER=""
_ACTIVE_PHASE_START=0
_PHASE_MIN_SPIN=0.3  # minimum visible spin time in seconds

_phase_timer_start() { _PHASE_START_TIMES["$1"]=$SECONDS; }

_phase_timer_elapsed() {
  local start="${_PHASE_START_TIMES["$1"]:-$SECONDS}"
  local elapsed=$((SECONDS - start))
  if [[ $elapsed -lt 1 ]]; then
    printf "<1s"
  else
    printf "%ss" "$elapsed"
  fi
}

# Start a phase with a spinner: phase_start "1/4" "Preflight"
phase_start() {
  local number="$1" name="$2"

  local current total
  IFS='/' read -r current total <<< "$number"
  _PHASE_CURRENT=$current
  _PHASE_TOTAL=$total
  _ACTIVE_PHASE_NAME="$name"
  _ACTIVE_PHASE_NUMBER="$number"

  _phase_timer_start "$name"

  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "  [%s] %s\n" "$number" "$name"
    return
  fi

  _ACTIVE_PHASE_START=$SECONDS
  spinner_start "$name"
}

# Update spinner status text: phase_update "checking git"
phase_update() {
  local text="$1"
  if [[ "$INTERACTIVE" == true ]] && _is_tty && [[ -n "$_SPINNER_STATUS_FILE" ]] && [[ -n "$_SPINNER_PID" ]]; then
    printf '%s' "$text" > "$_SPINNER_STATUS_FILE"
  else
    log_info "$text"
  fi
}

# End a phase: phase_end ok "git ✓  homebrew ✓"
phase_end() {
  local status="$1" detail="$2"
  local name="$_ACTIVE_PHASE_NAME"
  local timing
  timing="$(_phase_timer_elapsed "$name")"

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    # Enforce minimum spin duration so there's always visible motion.
    local elapsed=$((SECONDS - _ACTIVE_PHASE_START))
    if [[ $elapsed -lt 1 ]]; then
      sleep "$_PHASE_MIN_SPIN"
    fi

    # Kill spinner and clear line
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

    # Print resolved line with status, detail, and timing
    local sym
    case "$status" in
      ok)   sym="$_CHECK" ;;
      fail) sym="$_CROSS" ;;
      warn) sym="$_WARN"  ;;
      skip) sym="$_SKIP"  ;;
    esac

    # Format: "  ✓ Phase Name          detail text              <1s"
    _format_status_row "$sym" "$name" "$detail" "$timing"
    printf '\n'
  else
    # Non-TTY: simple output
    local sym_text
    case "$status" in
      ok)   sym_text="$_CHECK" ;;
      fail) sym_text="$_CROSS" ;;
      warn) sym_text="$_WARN"  ;;
      skip) sym_text="$_SKIP"  ;;
    esac
    printf "  %s %s — %s  %s\n" "$sym_text" "$name" "$detail" "$timing"
  fi

  _ACTIVE_PHASE_NAME=""
  _ACTIVE_PHASE_NUMBER=""
  _ACTIVE_PHASE_START=0
}

# End the phase spinner but leave the header line in place (no ✓ yet).
# Sub-steps will print beneath it. Call phase_resolve() when done.
phase_end_deferred() {
  _SUBSTEP_COUNT=0
  _SUBSTEP_CURSOR_DIRTY=0

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    # Enforce minimum spin duration
    local elapsed=$((SECONDS - _ACTIVE_PHASE_START))
    if [[ $elapsed -lt 1 ]]; then
      sleep "$_PHASE_MIN_SPIN"
    fi

    # Kill spinner and clear line
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

    # Print the phase name with a static loading indicator
    printf "  ${_CYAN}%s${_RST} %s\n" "$_BULLET_EMPTY" "$_ACTIVE_PHASE_NAME"
  else
    # Non-TTY: already printed by phase_start, nothing to do
    :
  fi
}

# Rewrite the deferred phase header with final status and timing.
# Must be called after all sub-steps have printed.
phase_resolve() {
  local status="$1" detail="$2"
  local name="$_ACTIVE_PHASE_NAME"
  local timing
  timing="$(_phase_timer_elapsed "$name")"

  local sym
  case "$status" in
    ok)   sym="$_CHECK" ;;
    fail) sym="$_CROSS" ;;
    warn) sym="$_WARN"  ;;
    skip) sym="$_SKIP"  ;;
  esac

  if [[ "$INTERACTIVE" == true ]] && _is_tty && [[ "${_SUBSTEP_CURSOR_DIRTY:-0}" -eq 0 ]]; then
    local lines_to_jump=$_SUBSTEP_COUNT

    # Move cursor up to the header line, clear it, rewrite
    if [[ $lines_to_jump -gt 0 ]]; then
      printf "\e[%dA" "$((lines_to_jump + 1))"
    else
      printf "\e[1A"
    fi
    printf "\e[2K"

    _format_status_row "$sym" "$name" "$detail" "$timing"
    printf '\n'

    # Erase substep lines — they served their purpose during execution
    if [[ $lines_to_jump -gt 0 ]]; then
      printf "\e[J"
    fi
  else
    # Non-TTY or dirty cursor: print a resolved summary line at current position
    _format_status_row "$sym" "$name" "$detail" "$timing"
    printf '\n'
  fi

  _ACTIVE_PHASE_NAME=""
  _ACTIVE_PHASE_NUMBER=""
  _ACTIVE_PHASE_START=0
  _SUBSTEP_COUNT=0
  _SUBSTEP_CURSOR_DIRTY=0
}

# Pause phase spinner for interactive prompts
phase_pause() {
  if [[ "$INTERACTIVE" == true ]] && _is_tty && [[ -n "${_SPINNER_PID:-}" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\e[2K"
    # Keep _SPINNER_STATUS_FILE and _ACTIVE_PHASE_* intact for resume
  fi
}

# Resume phase spinner after prompts
phase_resume() {
  if [[ "$INTERACTIVE" == true ]] && _is_tty && [[ -n "$_ACTIVE_PHASE_NAME" ]]; then
    spinner_start "$_ACTIVE_PHASE_NAME"
  fi
}

# Legacy compat — log_phase still works for --verbose / --dry-run paths
log_phase() {
  local number="$1" name="$2"
  local current total
  IFS='/' read -r current total <<< "$number"
  _PHASE_CURRENT=$current
  _PHASE_TOTAL=$total
  _phase_timer_start "$name"

  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "\n  [%s] %s\n\n" "$number" "$name"
    return
  fi

  printf "\n  ${_BOLD}%s${_RST}\n\n" "$name"
}

# ---------------------------------------------------------------------------
# Summary box
# ---------------------------------------------------------------------------

# Takes parallel arrays via nameref: statuses, labels, details, timings
# Each element: status=ok|fail|warn|skip, label=string, detail=string, timing=string
log_summary_box() {
  local -n _statuses=$1 _labels=$2 _details=$3 _timings=$4
  local total_time="$5"

  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "\n"
    local idx
    for idx in "${!_statuses[@]}"; do
      local sym
      case "${_statuses[$idx]}" in
        ok)   sym="$_CHECK" ;;
        fail) sym="$_CROSS" ;;
        warn) sym="$_WARN"  ;;
        skip) sym="$_SKIP"  ;;
      esac
      printf "  %s  %-20s %s\n" "$sym" "${_labels[$idx]}" "${_details[$idx]}"
    done
    printf "\n  Done in %s\n" "$total_time"
    return
  fi

  # Layout uses shared column constants from _format_status_row:
  # │ margin(2) sym(1) gap(1) label(_COL_LABEL) detail(_COL_DETAIL) gap(1) timing(_COL_TIMING) margin(2) │
  local w=$(( 2 + 1 + 1 + _COL_LABEL + _COL_DETAIL + 1 + _COL_TIMING + 2 ))

  # Header: "  Summary" left, total_time right
  local header_left="  ${_BOLD}Summary${_RST}"
  local header_right="${_DIM}${total_time}${_RST}  "
  local header_left_len=9   # "  Summary"
  local header_right_len=$((${#total_time} + 2))
  local header_gap=$((w - header_left_len - header_right_len))
  [[ $header_gap -lt 2 ]] && header_gap=2
  local header_spaces
  header_spaces="$(printf '%*s' "$header_gap" "")"

  printf "\n"
  _draw_box_top $w
  _draw_box_row $w "${header_left}${header_spaces}${header_right}"
  _draw_box_divider $w

  # Data rows
  local idx
  for idx in "${!_statuses[@]}"; do
    local sym
    case "${_statuses[$idx]}" in
      ok)   sym="$_CHECK" ;;
      fail) sym="$_CROSS" ;;
      warn) sym="$_WARN"  ;;
      skip) sym="$_SKIP"  ;;
    esac

    local label="${_labels[$idx]}"
    local detail="${_details[$idx]}"
    local timing="${_timings[$idx]}"

    # Pad each column using shared widths
    local label_padded
    label_padded="$(_pad_to_width "$_COL_LABEL" "$label")"
    if [[ ${#detail} -gt $_COL_DETAIL ]]; then
      detail="${detail:0:$((_COL_DETAIL - 1))}…"
    fi
    local detail_padded
    detail_padded="$(_pad_to_width "$_COL_DETAIL" "$detail")"
    local timing_padded
    timing_padded="$(printf '%*s' "$_COL_TIMING" "$timing")"

    local row_content
    case "${_statuses[$idx]}" in
      skip) row_content="  ${sym} ${_DIM}${label_padded}${detail_padded} ${timing_padded}${_RST}  " ;;
      *)    row_content="  ${sym} ${label_padded}${detail_padded} ${_DIM}${timing_padded}${_RST}  " ;;
    esac

    _draw_box_row $w "$row_content"
  done

  _draw_box_bottom $w
}
