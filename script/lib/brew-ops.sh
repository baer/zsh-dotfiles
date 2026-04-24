#!/usr/bin/env bash
#
# brew-ops.sh — shared Homebrew operation functions
#
# Source this file; do not execute it directly.
# Provides: brew_run_update, brew_run_upgrade, brew_run_bundle,
#           brew_detect_drift, brew_check_vulns
#
# Contract — callers must set before calling any function:
#   $VERBOSE        — boolean, controls spinner vs. direct output
#   $LOGFILE        — path to log file for command output
#   $DOTFILES_ROOT  — repo root
#   $BREWFILE       — path to Brewfile
#
# Callers must source these libs first (brew-ops.sh sources nothing):
#   lib/term.sh, lib/log.sh, lib/spinner.sh,
#   lib/brewfile.sh, lib/skip-lists.sh, lib/drift.sh

# Source guard
[[ -n "${_BREW_OPS_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_BREW_OPS_SH_LOADED=1

# ---------------------------------------------------------------------------
# brew_run_update — refresh the Homebrew index
# ---------------------------------------------------------------------------

brew_run_update() {
  if $VERBOSE; then
    log_info "brew update..."
    brew update 2>&1 | tee -a "$LOGFILE"
    log_success "brew update"
  else
    run_with_substep_spinner "brew update" "$LOGFILE" \
      brew update
  fi
}

# ---------------------------------------------------------------------------
# brew_run_upgrade — upgrade installed packages
#
# Distinguishes hard errors (disabled formulae, permission denied, locked)
# from soft skips (individual package failures).
# ---------------------------------------------------------------------------

brew_run_upgrade() {
  if $VERBOSE; then
    log_info "brew upgrade..."
    if brew upgrade 2>&1 | tee -a "$LOGFILE"; then
      log_success "brew upgrade"
    else
      local _upgrade_tail
      _upgrade_tail="$(tail -n 30 "$LOGFILE")"
      if echo "$_upgrade_tail" | grep -qE 'has been disabled|is not there|Permission denied|locked'; then
        log_error "brew upgrade (see ${LOGFILE##*/} for details)"
      else
        log_warn "brew upgrade (some packages skipped)"
      fi
    fi
  else
    substep_start "brew upgrade"
    if brew upgrade >> "$LOGFILE" 2>&1; then
      substep_stop ok "brew upgrade"
    else
      local _upgrade_tail
      _upgrade_tail="$(tail -n 30 "$LOGFILE")"
      if echo "$_upgrade_tail" | grep -qE 'has been disabled|is not there|Permission denied|locked'; then
        substep_stop fail "brew upgrade (errors in ${LOGFILE##*/})"
      else
        substep_stop warn "brew upgrade (some packages skipped)"
      fi
    fi
  fi
}

# ---------------------------------------------------------------------------
# brew_run_bundle — install from Brewfile, compute summary
#
# Sets _BREW_SUMMARY (e.g. "3 installed, 1 upgraded" or "all up to date").
# ---------------------------------------------------------------------------

_BREW_SUMMARY=""

brew_run_bundle() {
  local _log_lines_before
  _log_lines_before=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)

  if $VERBOSE; then
    log_info "brew bundle..."
    brew bundle --file="$BREWFILE" 2>&1 | tee -a "$LOGFILE"
    log_success "brew bundle"
  else
    run_with_substep_streaming_spinner "brew bundle" "$LOGFILE" \
      brew bundle --file="$BREWFILE"
  fi

  local _brew_installed=0
  local _brew_upgraded=0
  local _brew_using=0
  local _line
  while IFS= read -r _line; do
    case "$_line" in
      Installing\ *) _brew_installed=$((_brew_installed + 1)) ;;
      Upgrading\ *)  _brew_upgraded=$((_brew_upgraded + 1)) ;;
      Using\ *)      _brew_using=$((_brew_using + 1)) ;;
    esac
  done < <(tail -n +"$((_log_lines_before + 1))" "$LOGFILE")

  _BREW_SUMMARY=""
  if (( _brew_installed > 0 )); then
    _BREW_SUMMARY="${_brew_installed} installed"
  fi
  if (( _brew_upgraded > 0 )); then
    [[ -n "$_BREW_SUMMARY" ]] && _BREW_SUMMARY+=", "
    _BREW_SUMMARY+="${_brew_upgraded} upgraded"
  fi
  if [[ -z "$_BREW_SUMMARY" ]]; then
    _BREW_SUMMARY="all up to date"
  fi

  if $VERBOSE; then
    log_success "$_BREW_SUMMARY"
  fi
}

# ---------------------------------------------------------------------------
# brew_detect_drift — check for packages not in Brewfile
#
# Sets _DRIFT_COUNT (integer, or empty string if brew query failed).
# Caller decides what to do with the count.
# ---------------------------------------------------------------------------

_DRIFT_COUNT=""

brew_detect_drift() {
  if ! $VERBOSE; then
    substep_start "drift check"
  fi

  _DRIFT_COUNT=""
  local _audit_count
  _audit_count="$(_count_total_drift 2>/dev/null)" || _audit_count=""

  if [[ -z "$_audit_count" ]]; then
    _DRIFT_COUNT=""
    if $VERBOSE; then
      log_warn "drift check skipped: brew query failed (Homebrew may be broken)"
    else
      substep_stop warn "drift check (skipped — brew query failed)"
    fi
  elif [[ "$_audit_count" -gt 0 ]]; then
    _DRIFT_COUNT="$_audit_count"
    if $VERBOSE; then
      log_warn "$_audit_count packages not in Brewfile"
    else
      substep_stop warn "drift check ($_audit_count untracked)"
    fi
  else
    _DRIFT_COUNT=0
    if ! $VERBOSE; then
      substep_stop ok "drift check"
    fi
  fi
}

# ---------------------------------------------------------------------------
# brew_check_vulns — check for high-severity vulnerabilities
#
# Sets _VULN_COUNT (integer). Requires brew-vulns to be installed;
# silently returns 0 if not available.
# ---------------------------------------------------------------------------

_VULN_COUNT=0

brew_check_vulns() {
  if ! command -v brew-vulns &>/dev/null; then
    return 0
  fi

  if ! $VERBOSE; then
    substep_start "vuln check"
  fi

  _VULN_COUNT=0
  local _vuln_output=""

  if command -v gtimeout &>/dev/null; then
    _vuln_output="$(gtimeout 15 brew vulns --severity high 2>/dev/null)" || true
  else
    _vuln_output="$(brew vulns --severity high 2>/dev/null)" || true
  fi

  if [[ -n "$_vuln_output" ]]; then
    _VULN_COUNT="$(echo "$_vuln_output" | grep -cE '^[a-z].*\(' || true)"
  fi

  if $VERBOSE; then
    if [[ $_VULN_COUNT -gt 0 ]]; then
      log_warn "$_VULN_COUNT vulnerable packages"
    fi
  else
    if [[ $_VULN_COUNT -gt 0 ]]; then
      substep_stop warn "vuln check ($_VULN_COUNT vulnerable)"
    else
      substep_stop ok "vuln check"
    fi
  fi
}
