#!/usr/bin/env bash
#
# output.sh — shared output library for dotfiles scripts
#
# Source this file; do not execute it directly.
# Provides colored status output, spinners, box drawing, and prompts.
# Respects $NO_COLOR (https://no-color.org) and detects TTY.

# Source guard — prevent re-sourcing from wiping phase state
if [[ -n "${_OUTPUT_SH_LOADED:-}" ]]; then
  return 0 2>/dev/null || true
fi
_OUTPUT_SH_LOADED=1

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
# Box-drawing characters
# ---------------------------------------------------------------------------

_BOX_TL="╭" _BOX_TR="╮" _BOX_BL="╰" _BOX_BR="╯"
_BOX_H="─" _BOX_V="│" _BOX_DIV_L="├" _BOX_DIV_R="┤"
_BULLET="●" _BULLET_EMPTY="○"

# ---------------------------------------------------------------------------
# Box-drawing helpers (internal)
# ---------------------------------------------------------------------------
# All box functions take a width parameter (inner content width).

_draw_box_top() {
  local w="$1" line=""
  local i; for ((i=0; i<w; i++)); do line+="$_BOX_H"; done
  printf "  %s%s%s\n" "$_BOX_TL" "$line" "$_BOX_TR"
}

_draw_box_bottom() {
  local w="$1" line=""
  local i; for ((i=0; i<w; i++)); do line+="$_BOX_H"; done
  printf "  %s%s%s\n" "$_BOX_BL" "$line" "$_BOX_BR"
}

_draw_box_divider() {
  local w="$1" line=""
  local i; for ((i=0; i<w; i++)); do line+="$_BOX_H"; done
  printf "  %s%s%s\n" "$_BOX_DIV_L" "$line" "$_BOX_DIV_R"
}

# Print a row padded to width w. Content is left-aligned, padded with spaces.
_draw_box_row() {
  local w="$1" content="$2"
  # Strip ANSI codes to measure visible length
  local stripped
  stripped="$(printf '%s' "$content" | sed $'s/\e\\[[0-9;]*m//g')"
  local visible_len=${#stripped}
  local pad=$((w - visible_len))
  local spaces=""
  if [[ $pad -gt 0 ]]; then
    spaces="$(printf '%*s' "$pad" "")"
  fi
  printf "  %s%s%s%s\n" "$_BOX_V" "$content" "$spaces" "$_BOX_V"
}

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
# Status output
# ---------------------------------------------------------------------------

log_success() { printf "  %s %s\n" "$_CHECK" "$1"; }
log_error()   { printf "  %s %s\n" "$_CROSS" "$1" >&2; }
log_warn()    { printf "  %s %s\n" "$_WARN"  "$1"; }
log_skip()    { printf "  %s %s\n" "$_SKIP"  "${_DIM}$1${_RST}"; }
log_info()    { printf "  %s %s\n" "$_INFO"  "${_DIM}$1${_RST}"; }

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------

log_header() {
  local root="$1"
  local short_path="${root/#$HOME/~}"

  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "\n  dotfiles  %s\n\n" "$short_path"
    return
  fi

  # Fixed label: "  ● dotfiles" = 14 visible chars
  # Minimum gap: 4 spaces
  # Right side: path + 2 trailing spaces
  local label_vis_len=14  # "  ● dotfiles"
  local min_gap=4
  local right_margin=2
  local path_vis_len=${#short_path}

  local w=$((label_vis_len + min_gap + path_vis_len + right_margin))
  # Clamp to reasonable range
  [[ $w -lt 36 ]] && w=36
  [[ $w -gt 60 ]] && w=60

  # If path is too long for max width, truncate it
  local max_path=$((w - label_vis_len - min_gap - right_margin))
  if [[ $path_vis_len -gt $max_path ]]; then
    short_path="…${short_path: -$((max_path - 1))}"
  fi

  local label="  ${_CYAN}${_BULLET}${_RST} ${_BOLD}dotfiles${_RST}"
  local right="${_DIM}${short_path}${_RST}  "

  # Recalculate gap with actual content
  local right_actual_len=$((${#short_path} + right_margin))
  local gap=$((w - label_vis_len - right_actual_len))
  [[ $gap -lt 2 ]] && gap=2
  local spaces
  spaces="$(printf '%*s' "$gap" "")"

  printf "\n"
  _draw_box_top $w
  _draw_box_row $w "${label}${spaces}${right}"
  _draw_box_bottom $w
  printf "\n"
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
    # SECONDS is integer-resolution, so for sub-second phases we always
    # sleep the minimum. This guarantees each phase spinner is visible.
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

# Mark the substep cursor as dirty — call this when untracked lines are
# printed between phase_end_deferred and phase_resolve (e.g. interactive
# prompts). phase_resolve will skip cursor rewrite and print at current
# position instead.
substep_mark_dirty() { _SUBSTEP_CURSOR_DIRTY=1; }

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

# ---------------------------------------------------------------------------
# Celebration / completion
# ---------------------------------------------------------------------------

log_celebration() {
  local next_cmd="${1:-source ~/.zshrc}" elapsed="${2:-}"
  local timing=""
  [[ -n "$elapsed" ]] && timing=" in ${elapsed}"
  printf "\n  ${_GREEN}${_BOLD}✓ Done%s${_RST} ${_DIM}— happy hacking!${_RST}\n" "$timing"
  printf "\n  ${_DIM}Next →${_RST} ${_BOLD}%s${_RST}${_DIM}  or open a new terminal${_RST}\n\n" "$next_cmd"
}

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

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    # Size to terminal: min 80, max terminal width minus indent
    local term_w
    term_w="$(tput cols 2>/dev/null || printf '%s' "${COLUMNS:-80}")"
    local w=$((term_w - 4))  # 2-space indent + small margin
    [[ $w -lt 78 ]] && w=78

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

# ---------------------------------------------------------------------------
# Spinner
# ---------------------------------------------------------------------------

_SPINNER_PID=""
_SPINNER_FRAMES=( '⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏' )
_SPINNER_STATUS_FILE=""

spinner_start() {
  local message="$1"

  # Non-interactive: just print the message, no animation
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "  · %s\n" "$message"
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
      printf "\r\e[2K  ${_CYAN}%s${_RST} %s%s" "${_SPINNER_FRAMES[$((i % ${#_SPINNER_FRAMES[@]}))]}" "$message" "$extra"
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

  if [[ -n "$_SPINNER_STATUS_FILE" ]]; then
    rm -f "$_SPINNER_STATUS_FILE"
    _SPINNER_STATUS_FILE=""
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
  if [[ -n "${_SPINNER_STATUS_FILE:-}" ]]; then
    rm -f "$_SPINNER_STATUS_FILE"
    _SPINNER_STATUS_FILE=""
  fi
}

# ---------------------------------------------------------------------------
# Sub-step output (indented beneath a phase header)
# ---------------------------------------------------------------------------

_SUBSTEP_COUNT=0

substep_log_success() { printf "      %s %s\n" "$_CHECK" "$1"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_error()   { printf "      %s %s\n" "$_CROSS" "$1" >&2; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_warn()    { printf "      %s %s\n" "$_WARN"  "$1"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_info()    { printf "      %s %s\n" "$_INFO"  "${_DIM}$1${_RST}"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }

substep_start() {
  local message="$1"

  # Non-interactive: just print the message, no animation
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "      · %s\n" "$message"
    _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1))
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
      printf "\r\e[2K      ${_CYAN}%s${_RST} %s%s" "${_SPINNER_FRAMES[$((i % ${#_SPINNER_FRAMES[@]}))]}" "$message" "$extra"
      i=$((i + 1))
      sleep 0.08
    done
  ) &
  _SPINNER_PID=$!
}

substep_stop() {
  local status="$1" message="$2"

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

  case "$status" in
    ok)   substep_log_success "$message" ;;
    fail) substep_log_error   "$message" ;;
    warn) substep_log_warn    "$message" ;;
    skip) substep_log_info    "$message" ;;
  esac
}

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

# Numbered choice prompt. Returns the choice number (1-indexed).
# Usage: choice=$(prompt_choice "Action" "Skip" "Overwrite" "Backup")
prompt_choice() {
  local question="$1"
  shift
  local choices=("$@")
  local default=1

  # Display choices on one line
  local display=""
  local i
  for i in "${!choices[@]}"; do
    local n=$((i + 1))
    if [[ $n -eq $default ]]; then
      display+="${_BOLD}${n})${_RST} ${choices[$i]}   "
    else
      display+="${_DIM}${n})${_RST} ${choices[$i]}   "
    fi
  done
  printf "  %s\n" "$display" >&2

  printf "  ${_YELLOW}?${_RST} %s ${_DIM}(%d)${_RST}: " "$question" "$default" >&2
  local answer
  read -r answer
  answer="${answer:-$default}"

  # Validate
  if [[ "$answer" =~ ^[0-9]+$ ]] && [[ $answer -ge 1 ]] && [[ $answer -le ${#choices[@]} ]]; then
    printf "%d" "$answer"
  else
    printf "%d" "$default"
  fi
}
