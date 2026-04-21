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
