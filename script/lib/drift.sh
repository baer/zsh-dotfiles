#!/usr/bin/env bash
#
# drift.sh — collect packages installed but not in Brewfile
#
# Source this file; do not execute it directly.
# Requires BREWFILE to be set by the caller.
# Depends on: lib/brewfile.sh, lib/skip-lists.sh
# Provides _collect_drift_taps, _collect_drift_formulae,
#          _collect_drift_casks, _collect_drift_mas, _count_total_drift.

# Source guard
[[ -n "${_DRIFT_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_DRIFT_SH_LOADED=1

# Source dependencies
_DRIFT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=brewfile.sh
source "$_DRIFT_LIB_DIR/brewfile.sh"
# shellcheck source=skip-lists.sh
source "$_DRIFT_LIB_DIR/skip-lists.sh"

# Collect tap names installed but not in Brewfile.
# Prints one tap per line. Returns 0 even on brew failure (prints nothing).
_collect_drift_taps() {
  local installed_taps
  installed_taps="$(brew tap 2>/dev/null)" || return 0

  local expected_taps
  mapfile -t expected_taps < <(_brewfile_list_section "tap")

  while IFS= read -r tap; do
    [[ -z "$tap" ]] && continue
    # Skip implicit taps
    [[ "$tap" == "homebrew/core" || "$tap" == "homebrew/cask" || "$tap" == "homebrew/bundle" ]] && continue
    _is_audit_ignored "$tap" && continue
    local is_expected=false
    for t in "${expected_taps[@]:-}"; do
      [[ "$t" == "$tap" ]] && { is_expected=true; break; }
    done
    $is_expected || echo "$tap"
  done <<< "$installed_taps"
}

# Collect formula names installed (as leaves) but not in Brewfile.
# Prints one formula per line.
_collect_drift_formulae() {
  local leaves
  leaves="$(brew leaves 2>/dev/null)" || return 0

  while IFS= read -r leaf; do
    [[ -z "$leaf" ]] && continue
    _is_audit_ignored "$leaf" && continue
    _brewfile_contains "brew" "$leaf" || echo "$leaf"
  done <<< "$leaves"
}

# Collect cask names installed but not in Brewfile.
# Filters by skip list and ignore file.
# Prints one cask per line.
_collect_drift_casks() {
  local casks
  casks="$(brew list --cask 2>/dev/null)" || return 0

  while IFS= read -r cask; do
    [[ -z "$cask" ]] && continue
    _is_cask_skipped "$cask" && continue
    _is_audit_ignored "$cask" && continue
    _brewfile_contains "cask" "$cask" || echo "$cask"
  done <<< "$casks"
}

# Collect Mac App Store apps installed but not in Brewfile.
# Filters by skip list and ignore file.
# Prints "id name" per line (e.g. "999999999 Unknown App").
_collect_drift_mas() {
  command -v mas &>/dev/null || return 0
  local mas_list
  mas_list="$(mas list 2>/dev/null)" || return 0

  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local mas_id mas_name
    mas_id="$(echo "$line" | awk '{print $1}')"
    mas_name="$(echo "$line" | sed 's/^[0-9]* *//' | sed 's/ *(.*$//')"
    [[ -z "$mas_id" ]] && continue
    _is_apple_native_mas "$mas_id" && continue
    _is_mas_skipped "$mas_id" && continue
    _is_audit_ignored "$mas_id" && continue
    _brewfile_contains "mas" "$mas_id" || echo "$mas_id $mas_name"
  done <<< "$mas_list"
}

# Count total drift across all categories.
# Prints integer count to stdout.
_count_total_drift() {
  local count=0
  count=$(( count + $(_collect_drift_taps | grep -c '.' || true) ))
  count=$(( count + $(_collect_drift_formulae | grep -c '.' || true) ))
  count=$(( count + $(_collect_drift_casks | grep -c '.' || true) ))
  count=$(( count + $(_collect_drift_mas | grep -c '.' || true) ))
  echo "$count"
}
