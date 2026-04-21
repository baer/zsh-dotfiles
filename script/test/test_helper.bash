#!/usr/bin/env bash
# test_helper.bash — shared setup for bats tests
#
# Provides:
#   - FIXTURES_DIR pointing to script/test/fixtures/
#   - copy_fixture() to copy a fixture Brewfile to BATS_TEST_TMPDIR
#   - Stubs for log.sh functions (log_success, etc.)
#   - DOTFILES_ROOT and BREWFILE set for library sourcing

FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Stub log.sh functions so libraries don't need the real log.sh
log_success() { :; }
log_error() { :; }
log_warn() { :; }
log_skip() { :; }
log_info() { :; }

# Copy a fixture Brewfile to BATS_TEST_TMPDIR and set BREWFILE
copy_fixture() {
  local fixture="$1"
  cp "$FIXTURES_DIR/$fixture" "$BATS_TEST_TMPDIR/Brewfile"
  export BREWFILE="$BATS_TEST_TMPDIR/Brewfile"
}
