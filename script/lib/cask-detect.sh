#!/usr/bin/env bash
#
# cask-detect.sh — detect cask app artifacts on disk via jq
#
# Source this file; do not execute it directly.
# Requires jq to be installed.
# Provides _cask_app_artifacts, _cask_uninstall_artifacts, _cask_pkgutil_ids,
#          _is_cask_preinstalled, _find_orphaned_cask_apps.

# Source guard
[[ -n "${_CASK_DETECT_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_CASK_DETECT_SH_LOADED=1

_cask_detect_require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "cask-detect: jq is required but not installed" >&2
    return 1
  fi
}

# Extract app artifact paths from brew cask JSON on stdin.
# Prints one .app filename per line (e.g. "Slack.app").
_cask_app_artifacts() {
  jq -r '
    .casks[]?.artifacts[]? // empty
    | if type == "object" and has("app") then .app[]? else empty end
    | select(type == "string")
  '
}

# Extract uninstall.delete paths from brew cask JSON on stdin.
# Prints one path per line.
_cask_uninstall_artifacts() {
  jq -r '
    .casks[]?.artifacts[]? // empty
    | if type == "object" and has("uninstall") then
        .uninstall[]?.delete[]? // empty
      else empty end
    | select(type == "string")
  '
}

# Extract pkgutil receipt IDs from brew cask JSON on stdin.
# Handles both string and array values for pkgutil.
# Prints one ID per line.
_cask_pkgutil_ids() {
  jq -r '
    .casks[]?.artifacts[]? // empty
    | if type == "object" and has("uninstall") then
        .uninstall[]?.pkgutil // empty
      else empty end
    | if type == "string" then . elif type == "array" then .[]? else empty end
    | select(type == "string" and length > 0)
  '
}

# Check if a cask's app is already installed on disk (outside of Homebrew).
# Fetches brew info JSON once, then runs all three detection strategies.
# Sets _DETECTED_APP_PATH on success (for UI display).
# Args: cask_token
# Returns 0 if pre-installed, 1 if not.
_is_cask_preinstalled() {
  local cask="$1"
  _cask_detect_require_jq || return 1

  local json
  json=$(brew info --cask --json=v2 "$cask" 2>/dev/null || true)
  [[ -z "$json" ]] && return 1

  _DETECTED_APP_PATH=""

  # Strategy 1: Check app artifacts in /Applications
  local app
  while IFS= read -r app; do
    [[ -z "$app" ]] && continue
    if [[ -d "/Applications/$app" ]]; then
      _DETECTED_APP_PATH="$app"
      return 0
    fi
  done < <(echo "$json" | _cask_app_artifacts)

  # Strategy 2: Check uninstall.delete paths
  local app_path
  while IFS= read -r app_path; do
    [[ -z "$app_path" ]] && continue
    if [[ -d "$app_path" ]]; then
      _DETECTED_APP_PATH="$(basename "$app_path")"
      return 0
    fi
  done < <(echo "$json" | _cask_uninstall_artifacts)

  # Strategy 3: Check pkgutil receipts
  local pkg_id
  while IFS= read -r pkg_id; do
    [[ -z "$pkg_id" ]] && continue
    if pkgutil --pkg-info "$pkg_id" &>/dev/null; then
      _DETECTED_APP_PATH="(pkg: $pkg_id)"
      return 0
    fi
  done < <(echo "$json" | _cask_pkgutil_ids)

  return 1
}

# Find installed casks whose /Applications app path no longer exists.
# Makes a single bulk query for all installed casks.
# Prints "token|app_name" per line.
_find_orphaned_cask_apps() {
  _cask_detect_require_jq || return 1

  local json
  json="$(brew info --cask --json=v2 --installed 2>/dev/null || true)"
  [[ -z "$json" ]] && return 0

  echo "$json" | jq -r '
    .casks[]? |
    .token as $token |
    .artifacts[]? // empty |
    if type == "object" and has("app") then
      .app[]? | select(type == "string") | [$token, .] | join("|")
    else empty end
  ' | while IFS='|' read -r token app; do
    if [[ ! -d "/Applications/$app" ]]; then
      echo "${token}|${app}"
    fi
  done
}
