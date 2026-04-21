# Script Library Refactor — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the monolithic `script/lib/output.sh` (883 lines) into 6 focused libraries, deduplicate spinner/substep code, extract shared cask adoption logic, and add a check runner to brew-health — with zero behavioral changes.

**Architecture:** Pure restructuring. New libraries are extracted along existing section boundaries in output.sh. The spinner dedup parameterizes indent depth. A backward-compatible output.sh shim ensures nothing breaks during migration. Each main script migrates to sourcing only the libs it needs.

**Tech Stack:** Bash 5.x, shellcheck, `bash -n` syntax validation

**Spec:** `docs/specs/2026-04-20-script-lib-refactor-design.md`

---

## File Structure

### New files to create

| File | Purpose | Source |
|---|---|---|
| `script/lib/term.sh` | Terminal detection, colors, symbols, box-drawing | Extracted from output.sh |
| `script/lib/log.sh` | Status logging, header, celebration | Extracted from output.sh |
| `script/lib/spinner.sh` | Spinner/substep animation (deduplicated) | Rewritten from output.sh |
| `script/lib/prompt.sh` | Interactive user prompts | Extracted from output.sh |
| `script/lib/phase.sh` | Phase lifecycle, column formatting, summary box | Extracted from output.sh |
| `script/lib/error.sh` | Error context display, hint detection | Extracted from output.sh |
| `script/lib/adopt.sh` | Cask adoption primitives and full adoption flow | New, extracted from brew-audit + brew-skip-detect |

### Files to modify

| File | Changes |
|---|---|
| `script/lib/output.sh` | Replace 883-line body with ~15-line shim sourcing all 6 new libs |
| `script/lib/brewfile.sh` | Add explicit `source log.sh` dependency |
| `script/bootstrap` | Replace `source output.sh` with individual lib sources |
| `script/brew-audit` | Replace sources, remove `_adopt_cask` and `_remove_from_skip_list`, source adopt.sh |
| `script/brew-skip-detect` | Replace sources, use adopt.sh primitives instead of inline adoption logic |
| `script/brew-health` | Replace `source output.sh` with `source term.sh`, add check runner |

### Dependency graph (new libraries)

```
term.sh  (no dependencies)
  |-- log.sh --> term.sh
  |-- spinner.sh --> term.sh
  |-- prompt.sh --> term.sh
  |-- phase.sh --> term.sh, spinner.sh, log.sh
  +-- error.sh --> term.sh, log.sh
```

---

## Task 1: Create `term.sh`

**Files:**
- Create: `script/lib/term.sh`
- Reference: `script/lib/output.sh` (lines 1-101)

- [ ] **Step 1: Create `term.sh`**

Create `script/lib/term.sh` with the following content. This is extracted verbatim from `output.sh` with a new source guard.

```bash
#!/usr/bin/env bash
#
# term.sh — terminal capability detection and visual primitives
#
# Source this file; do not execute it directly.
# Provides color variables, status symbols, and box-drawing helpers.

# Source guard
[[ -n "${_TERM_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_TERM_SH_LOADED=1

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
# Box-drawing helpers
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
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n script/lib/term.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Verify functions are defined**

Run: `bash -c 'source script/lib/term.sh && type _is_tty && type _draw_box_row && echo "_CHECK=$_CHECK"'`
Expected: function definitions printed, `_CHECK` shows the green checkmark symbol

- [ ] **Step 4: Commit**

```bash
git add script/lib/term.sh
git commit -m "Add lib/term.sh: terminal detection, colors, symbols, box-drawing"
```

---

## Task 2: Create `log.sh` and `prompt.sh`

**Files:**
- Create: `script/lib/log.sh`
- Create: `script/lib/prompt.sh`
- Reference: `script/lib/output.sh` (lines 146-199, 523-529, 837-883)

- [ ] **Step 1: Create `log.sh`**

Create `script/lib/log.sh`. Content is extracted verbatim from `output.sh` — the `log_*` functions (lines 146-150), `log_header` (lines 156-199), and `log_celebration` (lines 523-529), with a new source guard and explicit `term.sh` dependency.

```bash
#!/usr/bin/env bash
#
# log.sh — status logging, header, and celebration output
#
# Source this file; do not execute it directly.
# Depends on: lib/term.sh

# Source guard
[[ -n "${_LOG_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_LOG_SH_LOADED=1

# Source dependencies
_LOG_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=term.sh
source "$_LOG_SH_DIR/term.sh"

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
# Celebration / completion
# ---------------------------------------------------------------------------

log_celebration() {
  local next_cmd="${1:-source ~/.zshrc}" elapsed="${2:-}"
  local timing=""
  [[ -n "$elapsed" ]] && timing=" in ${elapsed}"
  printf "\n  ${_GREEN}${_BOLD}✓ Done%s${_RST} ${_DIM}— happy hacking!${_RST}\n" "$timing"
  printf "\n  ${_DIM}Next →${_RST} ${_BOLD}%s${_RST}${_DIM}  or open a new terminal${_RST}\n\n" "$next_cmd"
}
```

- [ ] **Step 2: Verify log.sh syntax**

Run: `bash -n script/lib/log.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Create `prompt.sh`**

Create `script/lib/prompt.sh`. Content is extracted verbatim from `output.sh` lines 837-883 with a new source guard.

```bash
#!/usr/bin/env bash
#
# prompt.sh — interactive user prompts
#
# Source this file; do not execute it directly.
# Depends on: lib/term.sh

# Source guard
[[ -n "${_PROMPT_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_PROMPT_SH_LOADED=1

# Source dependencies
_PROMPT_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=term.sh
source "$_PROMPT_SH_DIR/term.sh"

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
```

- [ ] **Step 4: Verify prompt.sh syntax**

Run: `bash -n script/lib/prompt.sh`
Expected: no output, exit code 0

- [ ] **Step 5: Commit**

```bash
git add script/lib/log.sh script/lib/prompt.sh
git commit -m "Add lib/log.sh and lib/prompt.sh: extracted from output.sh"
```

---

## Task 3: Create `spinner.sh` (with deduplication)

This is the most complex task. `spinner_start`/`spinner_stop` and `substep_start`/`substep_stop` are near-identical (differing only in indent). This task creates a single parameterized implementation with thin wrappers.

**Files:**
- Create: `script/lib/spinner.sh`
- Reference: `script/lib/output.sh` (lines 648-831)

- [ ] **Step 1: Create `spinner.sh`**

Create `script/lib/spinner.sh`. The core animation code (`_spinner_start_impl`, `_spinner_stop_impl`) is parameterized by indent. Public functions (`spinner_start`/`stop`, `substep_start`/`stop`) are thin wrappers. The `run_with_substep_*` runners are moved verbatim.

```bash
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

  case "$status" in
    ok)   printf "%s%s %s\n" "$indent" "$_CHECK" "$message" ;;
    fail) printf "%s%s %s\n" "$indent" "$_CROSS" "$message" >&2 ;;
    warn) printf "%s%s %s\n" "$indent" "$_WARN"  "$message" ;;
    skip) printf "%s%s %s\n" "$indent" "$_SKIP"  "${_DIM}$message${_RST}" ;;
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
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n script/lib/spinner.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Verify spinner functions exist**

Run: `bash -c 'source script/lib/spinner.sh && type spinner_start && type substep_start && type _spinner_start_impl'`
Expected: all three show as functions

- [ ] **Step 4: Commit**

```bash
git add script/lib/spinner.sh
git commit -m "Add lib/spinner.sh: deduplicated spinner and substep animation"
```

---

## Task 4: Create `phase.sh` and `error.sh`

**Files:**
- Create: `script/lib/phase.sh`
- Create: `script/lib/error.sh`
- Reference: `script/lib/output.sh` (lines 104-517, 532-646)

- [ ] **Step 1: Create `phase.sh`**

Create `script/lib/phase.sh`. Content is extracted verbatim from `output.sh` — column formatting (lines 104-140), phase lifecycle (lines 203-433), and summary box (lines 438-517). New source guard with dependencies on `term.sh`, `spinner.sh`, and `log.sh` (phase_update calls log_info in its non-interactive fallback).

```bash
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
```

- [ ] **Step 2: Verify phase.sh syntax**

Run: `bash -n script/lib/phase.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Create `error.sh`**

Create `script/lib/error.sh`. Content is extracted verbatim from `output.sh` lines 532-646 with a new source guard. Depends on `term.sh` (box-drawing) and `log.sh` (`log_error`).

```bash
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
```

- [ ] **Step 4: Verify error.sh syntax**

Run: `bash -n script/lib/error.sh`
Expected: no output, exit code 0

- [ ] **Step 5: Commit**

```bash
git add script/lib/phase.sh script/lib/error.sh
git commit -m "Add lib/phase.sh and lib/error.sh: extracted from output.sh"
```

---

## Task 5: Convert `output.sh` to shim and verify

This is the atomic switch. Replace the 883-line body with a ~15-line shim that sources all 6 new libs. Since all 4 main scripts still `source output.sh`, this maintains backward compatibility while the migration happens.

**Files:**
- Modify: `script/lib/output.sh` (replace entire body)

- [ ] **Step 1: Replace output.sh with shim**

Replace the entire contents of `script/lib/output.sh` with:

```bash
#!/usr/bin/env bash
#
# output.sh — backward-compatible shim
#
# Sources all output sub-libraries. New scripts should source individual
# libs directly for faster loading and clearer dependencies.

# Source guard
[[ -n "${_OUTPUT_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_OUTPUT_SH_LOADED=1

_OUTPUT_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=term.sh
source "$_OUTPUT_SH_DIR/term.sh"
# shellcheck source=log.sh
source "$_OUTPUT_SH_DIR/log.sh"
# shellcheck source=spinner.sh
source "$_OUTPUT_SH_DIR/spinner.sh"
# shellcheck source=prompt.sh
source "$_OUTPUT_SH_DIR/prompt.sh"
# shellcheck source=phase.sh
source "$_OUTPUT_SH_DIR/phase.sh"
# shellcheck source=error.sh
source "$_OUTPUT_SH_DIR/error.sh"
```

- [ ] **Step 2: Verify shim syntax**

Run: `bash -n script/lib/output.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Verify shim loads all functions**

Run: `bash -c 'source script/lib/output.sh && type log_success && type spinner_start && type phase_start && type prompt_user && type log_error_context && type _draw_box_row'`
Expected: all six show as functions

- [ ] **Step 4: Verify all main scripts parse cleanly with the shim**

Run: `bash -n script/bootstrap && bash -n script/brew-audit && bash -n script/brew-health && bash -n script/brew-skip-detect && echo "All scripts parse OK"`
Expected: `All scripts parse OK`

- [ ] **Step 5: Run bootstrap dry-run to verify end-to-end**

Run: `script/bootstrap --dry-run`
Expected: The dry-run output prints normally with no errors. This confirms the shim loads all functions that bootstrap needs.

- [ ] **Step 6: Commit**

```bash
git add script/lib/output.sh
git commit -m "Convert output.sh to shim sourcing 6 focused libraries"
```

---

## Task 6: Update `brewfile.sh` with explicit `log.sh` dependency

`brewfile.sh` calls `log_success` in `_brewfile_insert` but never explicitly sources the library that defines it — it relies on callers having sourced `output.sh` first. Make this explicit.

**Files:**
- Modify: `script/lib/brewfile.sh` (lines 8-11)

- [ ] **Step 1: Add log.sh source to brewfile.sh**

In `script/lib/brewfile.sh`, after the source guard (line 11), add the dependency sourcing:

Replace:
```bash
_BREWFILE_SH_LOADED=1
```

With:
```bash
_BREWFILE_SH_LOADED=1

# Source dependencies
_BREWFILE_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=log.sh
source "$_BREWFILE_SH_DIR/log.sh"
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n script/lib/brewfile.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Commit**

```bash
git add script/lib/brewfile.sh
git commit -m "Add explicit log.sh dependency to brewfile.sh"
```

---

## Task 7: Create `adopt.sh`

Extract shared cask adoption primitives from `brew-audit` (lines 91-168) into a reusable library.

**Files:**
- Create: `script/lib/adopt.sh`

- [ ] **Step 1: Create `adopt.sh`**

```bash
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

  # Check if running
  if _app_is_running "$app_base"; then
    _prompt_quit_app "$app_base" || { log_info "Skipped $cask"; return 1; }
  fi

  # Trash the manual install
  if ! _trash_app "$app_path"; then
    log_info "Skipping adoption of $cask"
    return 1
  fi

  # Install via brew
  spinner_start "brew install --cask $cask"
  if brew install --cask "$cask" >> "$LOGFILE" 2>&1; then
    spinner_stop ok "brew install --cask $cask"
  else
    spinner_stop fail "brew install --cask $cask (see ${LOGFILE##*/} for details)"
    return 1
  fi

  # Update Brewfile if not already listed
  if ! grep -qx "cask '$cask'" "$BREWFILE"; then
    _brewfile_insert "cask" "$cask"
  fi

  # Remove from skip list if present
  _remove_from_skip_list "$cask"

  return 0
}
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n script/lib/adopt.sh`
Expected: no output, exit code 0

- [ ] **Step 3: Commit**

```bash
git add script/lib/adopt.sh
git commit -m "Add lib/adopt.sh: shared cask adoption primitives"
```

---

## Task 8: Migrate `bootstrap` to individual sources

Replace the single `source output.sh` with individual lib sources. Bootstrap uses everything, so it sources all 6 new libs directly.

**Files:**
- Modify: `script/bootstrap` (lines 13-14)

- [ ] **Step 1: Update source lines**

In `script/bootstrap`, replace:
```bash
# shellcheck source=lib/output.sh
source "$DOTFILES_ROOT/script/lib/output.sh"
```

With:
```bash
# shellcheck source=lib/term.sh
source "$DOTFILES_ROOT/script/lib/term.sh"
# shellcheck source=lib/log.sh
source "$DOTFILES_ROOT/script/lib/log.sh"
# shellcheck source=lib/spinner.sh
source "$DOTFILES_ROOT/script/lib/spinner.sh"
# shellcheck source=lib/prompt.sh
source "$DOTFILES_ROOT/script/lib/prompt.sh"
# shellcheck source=lib/phase.sh
source "$DOTFILES_ROOT/script/lib/phase.sh"
# shellcheck source=lib/error.sh
source "$DOTFILES_ROOT/script/lib/error.sh"
```

- [ ] **Step 2: Verify syntax**

Run: `bash -n script/bootstrap`
Expected: no output, exit code 0

- [ ] **Step 3: Run bootstrap dry-run**

Run: `script/bootstrap --dry-run`
Expected: Normal dry-run output with no errors

- [ ] **Step 4: Commit**

```bash
git add script/bootstrap
git commit -m "Migrate bootstrap to individual lib sources"
```

---

## Task 9: Migrate `brew-audit` to individual sources and `adopt.sh`

Replace `source output.sh` with individual libs, remove the `_remove_from_skip_list` and `_adopt_cask` functions (now in adopt.sh), and source adopt.sh instead.

**Files:**
- Modify: `script/brew-audit` (lines 15-16, 90-168)

- [ ] **Step 1: Update source lines**

In `script/brew-audit`, replace:
```bash
# shellcheck source=lib/output.sh
source "$DOTFILES_ROOT/script/lib/output.sh"
```

With:
```bash
# shellcheck source=lib/term.sh
source "$DOTFILES_ROOT/script/lib/term.sh"
# shellcheck source=lib/log.sh
source "$DOTFILES_ROOT/script/lib/log.sh"
# shellcheck source=lib/spinner.sh
source "$DOTFILES_ROOT/script/lib/spinner.sh"
# shellcheck source=lib/prompt.sh
source "$DOTFILES_ROOT/script/lib/prompt.sh"
# shellcheck source=lib/adopt.sh
source "$DOTFILES_ROOT/script/lib/adopt.sh"
```

- [ ] **Step 2: Remove `_remove_from_skip_list` function**

Delete the `_remove_from_skip_list` function (the block starting with `# Remove a cask from HOMEBREW_BUNDLE_CASK_SKIP in ~/.localrc` through the closing `}`). This is now in `adopt.sh`.

- [ ] **Step 3: Remove `_adopt_cask` function**

Delete the `_adopt_cask` function (the block starting with `# Adopt a manually installed app into brew management.` through the closing `}`). This is now in `adopt.sh`.

- [ ] **Step 4: Verify syntax**

Run: `bash -n script/brew-audit`
Expected: no output, exit code 0

- [ ] **Step 5: Verify the script still references all needed functions**

Run: `bash -c 'BREWFILE=/dev/null DOTFILES_ROOT=. source script/lib/adopt.sh && type _adopt_cask && type _remove_from_skip_list'`
Expected: both show as functions (confirming adopt.sh provides them)

- [ ] **Step 6: Commit**

```bash
git add script/brew-audit
git commit -m "Migrate brew-audit to individual lib sources and adopt.sh"
```

---

## Task 10: Migrate `brew-skip-detect` to individual sources and `adopt.sh`

Replace `source output.sh` with individual libs, source adopt.sh, and replace inline adoption logic with calls to the adopt.sh primitives.

**Files:**
- Modify: `script/brew-skip-detect` (lines 15-16, ~122-165)

**Note:** The refactored adoption path gains a re-check after the user says they quit the app (via `_prompt_quit_app`). The original brew-skip-detect code didn't re-check — this is a minor safety improvement, not a regression.

- [ ] **Step 1: Update source lines**

In `script/brew-skip-detect`, replace:
```bash
# shellcheck source=lib/output.sh
source "$DOTFILES_ROOT/script/lib/output.sh"
```

With:
```bash
# shellcheck source=lib/term.sh
source "$DOTFILES_ROOT/script/lib/term.sh"
# shellcheck source=lib/log.sh
source "$DOTFILES_ROOT/script/lib/log.sh"
# shellcheck source=lib/spinner.sh
source "$DOTFILES_ROOT/script/lib/spinner.sh"
# shellcheck source=lib/prompt.sh
source "$DOTFILES_ROOT/script/lib/prompt.sh"
# shellcheck source=lib/adopt.sh
source "$DOTFILES_ROOT/script/lib/adopt.sh"
```

- [ ] **Step 2: Replace inline adoption logic with adopt.sh primitives**

In the `_brew_skip_detect_main` function, inside the `case "$_app_response" in` block for option `2)` (Adopt into brew), replace the entire case body (from `# Adoption: find the app path and trash it` through the end of the `2)` case) with:

```bash
        2)
          # Adoption: find the app path and trash it
          local app_name=""
          app_name="$(echo "$detail" | sed 's/.*(\(.*\))/\1/')"

          if [[ -n "$app_name" ]] && [[ "$app_name" != *"pkg:"* ]]; then
            local app_base="${app_name%.app}"
            if _app_is_running "$app_base"; then
              if ! _prompt_quit_app "$app_base"; then
                log_info "Skipped $cask"
                continue
              fi
            fi

            if ! _trash_app "/Applications/$app_name"; then
              log_info "Skipping adoption of $cask"
              continue
            fi
            log_success "Moved $app_name to Trash"
          elif [[ "$app_name" == *"pkg:"* ]]; then
            log_warn "Package-based install detected for $cask — cannot auto-trash"
            log_info "Adding to skip list instead"
            _final_skip_casks+=("$cask")
            continue
          fi

          # Don't add to skip list — brew bundle will install it
          log_success "Adopted $cask — brew bundle will install it"
          ;;
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n script/brew-skip-detect`
Expected: no output, exit code 0

- [ ] **Step 4: Commit**

```bash
git add script/brew-skip-detect
git commit -m "Migrate brew-skip-detect to individual lib sources and adopt.sh"
```

---

## Task 11: Migrate `brew-health` to minimal sources and add check runner

brew-health only needs `term.sh` for color variables — it doesn't use log_*, spinners, prompts, or phases. Replace `source output.sh` with just `source term.sh`, and replace the manual check invocation with a runner loop.

**Files:**
- Modify: `script/brew-health` (lines 16-17, 340-364)

- [ ] **Step 1: Update source lines**

In `script/brew-health`, replace:
```bash
# shellcheck source=lib/output.sh
source "$DOTFILES_ROOT/script/lib/output.sh"
```

With:
```bash
# shellcheck source=lib/term.sh
source "$DOTFILES_ROOT/script/lib/term.sh"
```

- [ ] **Step 2: Replace manual check invocation with runner**

In `script/brew-health`, replace the entire "Run all checks" section (from the `# Run all checks` comment through the end of the file) with:

```bash
# ---------------------------------------------------------------------------
# Run all checks
# ---------------------------------------------------------------------------

_HEALTH_CHECKS=(
  _check_brew_reachable
  _check_update_lock
  _check_fsmonitor_taps
  _check_obsolete_taps
  _check_disabled_formulae
  _check_orphaned_casks
  _check_bundle_satisfaction
  _check_vulnerable_formulae
)

printf "\n  ${_BOLD}brew-health${_RST}\n\n"

for _check in "${_HEALTH_CHECKS[@]}"; do
  if ! "$_check"; then
    # First check is a gate — if Homebrew isn't reachable, bail
    if [[ "$_check" == "${_HEALTH_CHECKS[0]}" ]]; then
      printf "\n  ${_RED}${_BOLD}1 issue found${_RST} (Homebrew not reachable — remaining checks skipped)\n\n"
      exit 1
    fi
  fi
done

if [[ $_failures -eq 0 ]]; then
  printf "\n  ${_GREEN}${_BOLD}All checks passed${_RST}\n\n"
  exit 0
else
  printf "\n  ${_RED}${_BOLD}%d issue(s) found${_RST}\n\n" "$_failures"
  exit 1
fi
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n script/brew-health`
Expected: no output, exit code 0

- [ ] **Step 4: Run brew-health to verify**

Run: `script/brew-health`
Expected: Health checks run and produce output (pass or fail depending on system state). The important thing is no "command not found" errors — all color variables and check functions resolve correctly.

- [ ] **Step 5: Commit**

```bash
git add script/brew-health
git commit -m "Migrate brew-health to minimal sources, add check runner"
```

---

## Task 12: Final verification and cleanup

Verify all scripts work end-to-end and the output.sh shim is still functional.

**Files:**
- None modified (verification only)

- [ ] **Step 1: Syntax-check all libraries**

Run: `for f in script/lib/*.sh; do bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"; done`
Expected: all files show `OK`

- [ ] **Step 2: Syntax-check all main scripts**

Run: `for f in script/bootstrap script/brew-audit script/brew-health script/brew-skip-detect; do bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"; done`
Expected: all files show `OK`

- [ ] **Step 3: Verify output.sh shim still works**

Run: `bash -c 'source script/lib/output.sh && type log_success && type spinner_start && type phase_start && type prompt_user && type log_error_context'`
Expected: all show as functions. This confirms the shim is backward-compatible.

- [ ] **Step 4: Run bootstrap dry-run**

Run: `script/bootstrap --dry-run`
Expected: Normal dry-run output

- [ ] **Step 5: Run brew-health**

Run: `script/brew-health`
Expected: Health checks run with no "command not found" errors

- [ ] **Step 6: Verify no function is defined in output.sh directly**

Run: `grep -c '()' script/lib/output.sh`
Expected: `0` — output.sh is a pure shim with no function definitions

- [ ] **Step 7: Verify line counts improved**

Run: `wc -l script/lib/*.sh | sort -n`
Expected: No single file exceeds ~350 lines. `output.sh` should be ~25 lines.

- [ ] **Step 8: Summary commit (if any fixups were needed)**

Only if previous steps required fixes:
```bash
git add -A
git commit -m "Fix issues found during final verification"
```

---

## Task Dependencies

```
Task 1 (term.sh)
  |
  +---> Task 2 (log.sh, prompt.sh)
  |       |
  |       +---> Task 4 (phase.sh, error.sh)
  |
  +---> Task 3 (spinner.sh)
  |       |
  |       +---> Task 4 (phase.sh, error.sh)
  |
  +------+---> Task 5 (output.sh shim) -- depends on Tasks 1-4
                |
                +---> Task 8 (migrate bootstrap)
                +---> Task 11 (migrate brew-health)

Task 6 (brewfile.sh) -- independent, can run anytime after Task 2
Task 7 (adopt.sh) -- depends on Tasks 1-3

Task 7 --+---> Task 9 (migrate brew-audit) -- depends on Tasks 5, 7
          +---> Task 10 (migrate brew-skip-detect) -- depends on Tasks 5, 7

Tasks 8-11 ---> Task 12 (final verification)
```

**Parallelizable groups:**
- Tasks 1-3 can run in sequence (fast, foundational)
- Task 4 depends on Tasks 2-3
- Tasks 6, 7 can run in parallel with Task 5
- Tasks 8-11 can run in parallel (each migrates one script independently)
- Task 12 runs last
