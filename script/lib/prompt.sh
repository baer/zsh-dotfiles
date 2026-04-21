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
