#!/usr/bin/env bash
#
# output.sh — shared output library for dotfiles scripts
#
# Source this file; do not execute it directly.
# Provides colored status output, spinners, box drawing, and prompts.
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
# Phase tracking with dot-track progress
# ---------------------------------------------------------------------------

declare -A _PHASE_START_TIMES=()
_PHASE_TOTAL=4
_PHASE_CURRENT=0

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

log_phase() {
  local number="$1" name="$2"

  # Parse "1/4" format
  local current total
  IFS='/' read -r current total <<< "$number"
  _PHASE_CURRENT=$current
  _PHASE_TOTAL=$total

  _phase_timer_start "$name"

  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "\n  [%s] %s\n\n" "$number" "$name"
    return
  fi

  # Build dot track
  local dots=""
  local i
  for ((i=1; i<=total; i++)); do
    if [[ $i -le $current ]]; then
      dots+="${_CYAN}${_BULLET}${_RST} "
    else
      dots+="${_DIM}${_BULLET_EMPTY}${_RST} "
    fi
  done

  printf "\n  %s ${_BOLD}%s${_RST}\n\n" "$dots" "$name"
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

  # Layout: │ LL sym LL label(16) LL detail(flexible) LL timing(5) LL │
  # LL = literal spaces. Fixed columns: margins(2+2) + sym(1) + gaps(3) + label(16) + timing(5) = 29
  # So detail_space = w - 29
  local w=50

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
  local detail_space=$((w - 29))
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

    # Pad each column
    local label_padded
    label_padded="$(printf '%-16s' "$label")"
    if [[ ${#detail} -gt $detail_space ]]; then
      detail="${detail:0:$((detail_space - 1))}…"
    fi
    local detail_padded
    detail_padded="$(printf '%-*s' "$detail_space" "$detail")"
    local timing_padded
    timing_padded="$(printf '%5s' "$timing")"

    local row_content
    case "${_statuses[$idx]}" in
      skip) row_content="  ${sym}  ${_DIM}${label_padded}${detail_padded} ${timing_padded}${_RST}  " ;;
      *)    row_content="  ${sym}  ${label_padded}${detail_padded} ${_DIM}${timing_padded}${_RST}  " ;;
    esac

    _draw_box_row $w "$row_content"
  done

  _draw_box_bottom $w
}

# ---------------------------------------------------------------------------
# Celebration / completion
# ---------------------------------------------------------------------------

log_celebration() {
  local next_cmd="${1:-source ~/.zshrc}"
  printf "\n  ${_GREEN}${_BOLD}✓ All set!${_RST}\n"
  printf "\n  ${_DIM}Next →${_RST} ${_BOLD}%s${_RST}${_DIM}  or open a new terminal${_RST}\n\n" "$next_cmd"
}

# ---------------------------------------------------------------------------
# Error context with hints
# ---------------------------------------------------------------------------

log_error_context() {
  local logfile="$1" phase="${2:-}"
  local tail_lines=5

  if [[ -n "$phase" ]]; then
    log_error "Failed during: $phase"
  fi

  if [[ ! -f "$logfile" ]] || [[ ! -s "$logfile" ]]; then
    return
  fi

  local logname="${logfile##*/}"

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    local w=46
    local header_content="─ ${logname} (last ${tail_lines} lines) "
    local header_len=${#header_content}
    local remaining=$((w - header_len - 1))
    local header_pad=""
    local i; for ((i=0; i<remaining; i++)); do header_pad+="$_BOX_H"; done

    printf "\n  %s%s%s%s\n" "$_BOX_TL" "$_BOX_H" "${_DIM}${header_content}${_RST}" "${header_pad}${_BOX_TR}"

    while IFS= read -r line; do
      # Truncate long lines to fit box
      if [[ ${#line} -gt $((w - 4)) ]]; then
        line="${line:0:$((w - 5))}…"
      fi
      _draw_box_row $w "  ${_DIM}${line}${_RST}"
    done < <(tail -n "$tail_lines" "$logfile")

    _draw_box_bottom $w
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
# Run a command with a streaming spinner — updates status from stdout
# ---------------------------------------------------------------------------
# Parses lines matching "Installing|Upgrading|Using <name>" and shows
# the current package name next to the spinner message.

run_with_streaming_spinner() {
  local message="$1" logfile="$2"
  shift 2

  spinner_start "$message"

  local exit_code_file
  exit_code_file="$(mktemp "${TMPDIR:-/tmp}/.dotfiles_exit.XXXXXX")"

  # Run command, tee to logfile, parse output for status updates
  {
    "$@" 2>&1 || echo $? > "$exit_code_file"
  } | while IFS= read -r line; do
    printf '%s\n' "$line" >> "$logfile"
    # Extract package name from brew bundle output
    local pkg=""
    if [[ "$line" =~ ^(Installing|Upgrading|Using)[[:space:]]+(.+)$ ]]; then
      pkg="${BASH_REMATCH[2]}"
      # Clean up: remove version info and extra details
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
    spinner_stop ok "$message"
  else
    spinner_stop fail "$message (see ${logfile##*/} for details)"
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
