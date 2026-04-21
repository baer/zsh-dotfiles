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
