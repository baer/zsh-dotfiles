#!/usr/bin/env bash
#
# skip-lists.sh — predicates for Homebrew skip lists and audit ignore file
#
# Source this file; do not execute it directly.
# Provides _is_cask_skipped, _is_mas_skipped, _is_audit_ignored,
#          _is_audit_ignored_local.

# Source guard
[[ -n "${_SKIP_LISTS_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_SKIP_LISTS_SH_LOADED=1

# Check if a cask is in the HOMEBREW_BUNDLE_CASK_SKIP space-separated list.
# Returns 0 if skipped, 1 if not.
_is_cask_skipped() {
  local cask="$1"
  echo " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " | grep -q " $cask "
}

# Check if a mas app ID is in the HOMEBREW_BUNDLE_MAS_SKIP space-separated list.
# Returns 0 if skipped, 1 if not.
_is_mas_skipped() {
  local id="$1"
  echo " ${HOMEBREW_BUNDLE_MAS_SKIP:-} " | grep -q " $id "
}

# Check if a mas app is an Apple-native app (bundle ID starts with com.apple.).
# Uses Spotlight metadata; returns 1 (not Apple) if lookup fails.
_is_apple_native_mas() {
  local mas_id="$1"
  local app_path
  app_path="$(mdfind "kMDItemAppStoreAdamID == $mas_id" 2>/dev/null | head -1)"
  [[ -z "$app_path" ]] && return 1
  local bundle_id
  bundle_id="$(mdls -name kMDItemCFBundleIdentifier -raw "$app_path" 2>/dev/null)"
  [[ "$bundle_id" == com.apple.* ]]
}

# Check if a package name is in the audit ignore file.
# Returns 0 if ignored, 1 if not (or if the file doesn't exist).
_is_audit_ignored() {
  local name="$1"
  local ignore_file="${AUDIT_IGNORE_FILE:-$HOME/.brew-audit-ignore}"
  [[ -f "$ignore_file" ]] && grep -qx "$name" "$ignore_file" 2>/dev/null
}

# Check if a package name is in the local (machine-specific) audit ignore file.
# Returns 0 if ignored, 1 if not (or if the file doesn't exist).
_is_audit_ignored_local() {
  local name="$1"
  local ignore_file="${AUDIT_IGNORE_LOCAL_FILE:-$HOME/.brew-audit-ignore-local}"
  [[ -f "$ignore_file" ]] && grep -qx "$name" "$ignore_file" 2>/dev/null
}
