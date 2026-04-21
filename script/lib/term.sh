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
