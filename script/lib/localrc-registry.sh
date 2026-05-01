#!/usr/bin/env bash
#
# localrc-registry.sh — single source of truth for repo-managed ~/.localrc vars
#
# Source this file; do not execute it directly.

[[ -n "${_LOCALRC_REGISTRY_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_LOCALRC_REGISTRY_SH_LOADED=1

_localrc_registry_groups() {
  printf '%s\n' editor xdg homebrew
}

_localrc_registry_group_label() {
  case "$1" in
    editor) printf '%s\n' "Editor and agent" ;;
    xdg) printf '%s\n' "XDG base directories" ;;
    homebrew) printf '%s\n' "Homebrew skip lists" ;;
    *) return 1 ;;
  esac
}

_localrc_registry_vars_in() {
  case "$1" in
    editor) printf '%s\n' EDITOR AGENT ;;
    xdg) printf '%s\n' XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME ;;
    homebrew) printf '%s\n' HOMEBREW_BUNDLE_CASK_SKIP HOMEBREW_BUNDLE_MAS_SKIP ;;
    *) return 1 ;;
  esac
}

_localrc_registry_all_vars() {
  local group
  while IFS= read -r group; do
    _localrc_registry_vars_in "$group"
  done < <(_localrc_registry_groups)
}

_localrc_registry_default() {
  case "$1" in
    EDITOR) printf '%s\n' "code" ;;
    AGENT) printf '%s\n' "claude" ;;
    XDG_CONFIG_HOME) printf '%s\n' "\$HOME/.config" ;;
    XDG_DATA_HOME) printf '%s\n' "\$HOME/.local/share" ;;
    XDG_CACHE_HOME) printf '%s\n' "\$HOME/.cache" ;;
    XDG_STATE_HOME) printf '%s\n' "\$HOME/.local/state" ;;
    HOMEBREW_BUNDLE_CASK_SKIP|HOMEBREW_BUNDLE_MAS_SKIP) : ;;
    *) return 1 ;;
  esac
}

_localrc_registry_description() {
  case "$1" in
    EDITOR) printf '%s\n' "Editor used by e/ee/git helpers" ;;
    AGENT) printf '%s\n' "Agent CLI launched by bin/a" ;;
    XDG_CONFIG_HOME) printf '%s\n' "Base directory for config files" ;;
    XDG_DATA_HOME) printf '%s\n' "Base directory for local app data" ;;
    XDG_CACHE_HOME) printf '%s\n' "Base directory for caches" ;;
    XDG_STATE_HOME) printf '%s\n' "Base directory for local state" ;;
    HOMEBREW_BUNDLE_CASK_SKIP) printf '%s\n' "Homebrew casks to skip on this machine (space-separated)" ;;
    HOMEBREW_BUNDLE_MAS_SKIP) printf '%s\n' "Mac App Store IDs to skip on this machine (space-separated)" ;;
    *) return 1 ;;
  esac
}
