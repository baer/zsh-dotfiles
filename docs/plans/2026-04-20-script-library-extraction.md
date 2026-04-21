# Script Library Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract duplicated domain logic from script/ into shared libraries, replace inline Python with jq, and add bats-core tests.

**Architecture:** Four new libraries (skip-lists.sh, brewfile.sh, cask-detect.sh, drift.sh) extract shared logic from the four orchestrator scripts. Libraries follow the existing output.sh sourcing pattern with double-source guards. Tests use bats-core with function-level mocking of `brew`/`mas` commands.

**Tech Stack:** Bash, bats-core (test framework), jq (JSON parsing, replaces python3)

**Spec:** `docs/specs/2026-04-20-script-library-extraction-design.md`

---

### Task 1: Test scaffolding and Brewfile setup

**Files:**
- Modify: `Brewfile:29` (add bats-core)
- Create: `test/test_helper.bash`
- Create: `test/fixtures/Brewfile.basic`
- Create: `test/fixtures/Brewfile.full`
- Create: `test/fixtures/Brewfile.empty`

- [ ] **Step 1: Add bats-core to Brewfile**

Insert `brew 'bats-core'` between `brew 'bat'` and `brew 'btop'` in the Brewfile:

```
brew 'bat'
brew 'bats-core'
brew 'btop'
```

- [ ] **Step 2: Install bats-core**

Run: `brew install bats-core`
Expected: bats-core installed successfully

- [ ] **Step 3: Create test fixture — Brewfile.empty**

Create `test/fixtures/Brewfile.empty` as an empty file (zero bytes).

- [ ] **Step 4: Create test fixture — Brewfile.basic**

Create `test/fixtures/Brewfile.basic`:

```
tap 'homebrew/bundle'
tap 'homebrew/cask-fonts'

brew 'git'
brew 'jq'
brew 'wget'

cask '1password'
cask 'firefox'
cask 'google-chrome'
```

- [ ] **Step 5: Create test fixture — Brewfile.full**

Create `test/fixtures/Brewfile.full`:

```
tap 'homebrew/bundle'
tap 'homebrew/cask-fonts'
tap 'nikitabobko/tap'

brew 'atuin'
brew 'bat'
brew 'git'
brew 'jq'
brew 'mas'
brew 'wget'

cask '1password'
cask 'firefox'
cask 'ghostty'
cask 'google-chrome'
cask 'slack'

mas 'Keynote', id: 409183694
mas 'Numbers', id: 409203825
mas 'Pages', id: 409201541
mas 'Xcode', id: 497799835
```

- [ ] **Step 6: Create test_helper.bash**

Create `test/test_helper.bash`:

```bash
#!/usr/bin/env bash
# test_helper.bash — shared setup for bats tests
#
# Provides:
#   - FIXTURES_DIR pointing to test/fixtures/
#   - copy_fixture() to copy a fixture Brewfile to BATS_TEST_TMPDIR
#   - Stubs for output.sh functions (log_success, etc.)
#   - DOTFILES_ROOT and BREWFILE set for library sourcing

FIXTURES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/fixtures" && pwd)"
DOTFILES_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Stub output.sh functions so libraries don't need the real output.sh
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
```

- [ ] **Step 7: Verify bats can find the test helper**

Run: `cd /Users/eric.baer/workspace/zsh-dotfiles && bats --version`
Expected: version number printed (e.g. `Bats 1.x.x`)

- [ ] **Step 8: Commit**

```bash
git add Brewfile test/test_helper.bash test/fixtures/Brewfile.basic test/fixtures/Brewfile.full test/fixtures/Brewfile.empty
git commit -m "Add bats-core test scaffolding and Brewfile fixtures"
```

---

### Task 2: Create lib/skip-lists.sh with tests

**Files:**
- Create: `test/lib/skip-lists.bats`
- Create: `script/lib/skip-lists.sh`

This library has zero dependencies — simplest to build first.

- [ ] **Step 1: Write failing tests**

Create `test/lib/skip-lists.bats`:

```bash
#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
}

# --- _is_cask_skipped ---

@test "_is_cask_skipped returns 0 when cask is in skip list" {
  export HOMEBREW_BUNDLE_CASK_SKIP="slack zoom firefox"
  run _is_cask_skipped "zoom"
  [ "$status" -eq 0 ]
}

@test "_is_cask_skipped returns 1 when cask is not in skip list" {
  export HOMEBREW_BUNDLE_CASK_SKIP="slack zoom"
  run _is_cask_skipped "firefox"
  [ "$status" -eq 1 ]
}

@test "_is_cask_skipped returns 1 when skip list is empty" {
  unset HOMEBREW_BUNDLE_CASK_SKIP
  run _is_cask_skipped "firefox"
  [ "$status" -eq 1 ]
}

@test "_is_cask_skipped does not partial match" {
  export HOMEBREW_BUNDLE_CASK_SKIP="firefox-nightly"
  run _is_cask_skipped "firefox"
  [ "$status" -eq 1 ]
}

# --- _is_mas_skipped ---

@test "_is_mas_skipped returns 0 when id is in skip list" {
  export HOMEBREW_BUNDLE_MAS_SKIP="409183694 497799835"
  run _is_mas_skipped "497799835"
  [ "$status" -eq 0 ]
}

@test "_is_mas_skipped returns 1 when id is not in skip list" {
  export HOMEBREW_BUNDLE_MAS_SKIP="409183694"
  run _is_mas_skipped "497799835"
  [ "$status" -eq 1 ]
}

@test "_is_mas_skipped returns 1 when skip list is empty" {
  unset HOMEBREW_BUNDLE_MAS_SKIP
  run _is_mas_skipped "409183694"
  [ "$status" -eq 1 ]
}

# --- _is_audit_ignored ---

@test "_is_audit_ignored returns 0 when package is in ignore file" {
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/ignore"
  printf "slack\nzoom\nfirefox\n" > "$AUDIT_IGNORE_FILE"
  run _is_audit_ignored "zoom"
  [ "$status" -eq 0 ]
}

@test "_is_audit_ignored returns 1 when package is not in ignore file" {
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/ignore"
  printf "slack\nzoom\n" > "$AUDIT_IGNORE_FILE"
  run _is_audit_ignored "firefox"
  [ "$status" -eq 1 ]
}

@test "_is_audit_ignored returns 1 when ignore file does not exist" {
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/nonexistent"
  run _is_audit_ignored "slack"
  [ "$status" -eq 1 ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats test/lib/skip-lists.bats`
Expected: All tests FAIL (source file not found)

- [ ] **Step 3: Write implementation**

Create `script/lib/skip-lists.sh`:

```bash
#!/usr/bin/env bash
#
# skip-lists.sh — predicates for Homebrew skip lists and audit ignore file
#
# Source this file; do not execute it directly.
# Provides _is_cask_skipped, _is_mas_skipped, _is_audit_ignored.

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

# Check if a package name is in the audit ignore file.
# Returns 0 if ignored, 1 if not (or if the file doesn't exist).
_is_audit_ignored() {
  local name="$1"
  local ignore_file="${AUDIT_IGNORE_FILE:-$HOME/.brew-audit-ignore}"
  [[ -f "$ignore_file" ]] && grep -qx "$name" "$ignore_file" 2>/dev/null
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/lib/skip-lists.bats`
Expected: All 10 tests PASS

- [ ] **Step 5: Commit**

```bash
git add script/lib/skip-lists.sh test/lib/skip-lists.bats
git commit -m "Add lib/skip-lists.sh with skip-list and ignore-file predicates"
```

---

### Task 3: Create lib/brewfile.sh with tests

**Files:**
- Create: `test/lib/brewfile.bats`
- Create: `script/lib/brewfile.sh`

- [ ] **Step 1: Write failing tests**

Create `test/lib/brewfile.bats`:

```bash
#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/brewfile.sh"
}

# --- _brewfile_list_section ---

@test "_brewfile_list_section tap lists tap names" {
  copy_fixture "Brewfile.full"
  run _brewfile_list_section "tap"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "homebrew/bundle" ]
  [ "${lines[1]}" = "homebrew/cask-fonts" ]
  [ "${lines[2]}" = "nikitabobko/tap" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "_brewfile_list_section brew lists formula names" {
  copy_fixture "Brewfile.basic"
  run _brewfile_list_section "brew"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "git" ]
  [ "${lines[1]}" = "jq" ]
  [ "${lines[2]}" = "wget" ]
}

@test "_brewfile_list_section cask lists cask names" {
  copy_fixture "Brewfile.basic"
  run _brewfile_list_section "cask"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "1password" ]
  [ "${lines[1]}" = "firefox" ]
  [ "${lines[2]}" = "google-chrome" ]
}

@test "_brewfile_list_section mas lists mas names" {
  copy_fixture "Brewfile.full"
  run _brewfile_list_section "mas"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Keynote" ]
  [ "${lines[1]}" = "Numbers" ]
  [ "${lines[2]}" = "Pages" ]
  [ "${lines[3]}" = "Xcode" ]
}

@test "_brewfile_list_section returns empty for missing section" {
  copy_fixture "Brewfile.basic"
  run _brewfile_list_section "mas"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

@test "_brewfile_list_section returns empty for empty file" {
  copy_fixture "Brewfile.empty"
  run _brewfile_list_section "brew"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

# --- _brewfile_contains ---

@test "_brewfile_contains finds existing formula" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "brew" "git"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains rejects missing formula" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "brew" "curl"
  [ "$status" -eq 1 ]
}

@test "_brewfile_contains finds existing cask" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "cask" "firefox"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains rejects missing cask" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "cask" "slack"
  [ "$status" -eq 1 ]
}

@test "_brewfile_contains finds existing tap" {
  copy_fixture "Brewfile.basic"
  run _brewfile_contains "tap" "homebrew/bundle"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains finds mas entry by id" {
  copy_fixture "Brewfile.full"
  run _brewfile_contains "mas" "409183694"
  [ "$status" -eq 0 ]
}

@test "_brewfile_contains rejects missing mas id" {
  copy_fixture "Brewfile.full"
  run _brewfile_contains "mas" "999999999"
  [ "$status" -eq 1 ]
}

# --- _brewfile_insert ---

@test "_brewfile_insert adds formula in sorted position (middle)" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "brew" "fzf"
  run grep "^brew " "$BREWFILE"
  [ "${lines[0]}" = "brew 'fzf'" ]
  [ "${lines[1]}" = "brew 'git'" ]
  [ "${lines[2]}" = "brew 'jq'" ]
  [ "${lines[3]}" = "brew 'wget'" ]
}

@test "_brewfile_insert adds formula in sorted position (beginning)" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "brew" "ack"
  run grep "^brew " "$BREWFILE"
  [ "${lines[0]}" = "brew 'ack'" ]
  [ "${lines[1]}" = "brew 'git'" ]
}

@test "_brewfile_insert adds formula in sorted position (end)" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "brew" "zsh"
  run grep "^brew " "$BREWFILE"
  [ "${lines[3]}" = "brew 'zsh'" ]
}

@test "_brewfile_insert adds cask in sorted position" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "cask" "docker"
  run grep "^cask " "$BREWFILE"
  [ "${lines[0]}" = "cask '1password'" ]
  [ "${lines[1]}" = "cask 'docker'" ]
  [ "${lines[2]}" = "cask 'firefox'" ]
  [ "${lines[3]}" = "cask 'google-chrome'" ]
}

@test "_brewfile_insert adds mas entry with id in sorted position" {
  copy_fixture "Brewfile.full"
  _brewfile_insert "mas" "GarageBand" "682658836"
  run grep "^mas " "$BREWFILE"
  [ "${lines[0]}" = "mas 'GarageBand', id: 682658836" ]
  [ "${lines[1]}" = "mas 'Keynote', id: 409183694" ]
}

@test "_brewfile_insert creates new section when missing" {
  copy_fixture "Brewfile.basic"
  _brewfile_insert "mas" "Keynote" "409183694"
  # Should have a blank line before the new section
  run grep -c "^mas " "$BREWFILE"
  [ "$output" = "1" ]
  run grep "^mas " "$BREWFILE"
  [ "${lines[0]}" = "mas 'Keynote', id: 409183694" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats test/lib/brewfile.bats`
Expected: All tests FAIL (source file not found)

- [ ] **Step 3: Write implementation**

Create `script/lib/brewfile.sh`:

```bash
#!/usr/bin/env bash
#
# brewfile.sh — Brewfile parsing and mutation
#
# Source this file; do not execute it directly.
# Requires BREWFILE to be set by the caller.
# Provides _brewfile_list_section, _brewfile_contains, _brewfile_insert.

# Source guard
[[ -n "${_BREWFILE_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_BREWFILE_SH_LOADED=1

# List names in a Brewfile section, one per line.
# Args: type ("tap"|"brew"|"cask"|"mas")
_brewfile_list_section() {
  local type="$1"
  [[ -f "$BREWFILE" ]] || return 0
  if [[ "$type" == "mas" ]]; then
    grep "^mas '" "$BREWFILE" | awk -F"'" '{print $2}'
  else
    grep "^${type} '" "$BREWFILE" | awk -F"'" '{print $2}'
  fi
}

# Check if a package is in the Brewfile.
# Args: type ("tap"|"brew"|"cask"|"mas"), name (for mas: numeric id)
# Returns 0 if present, 1 if not.
_brewfile_contains() {
  local type="$1" name="$2"
  [[ -f "$BREWFILE" ]] || return 1
  if [[ "$type" == "mas" ]]; then
    grep -q "id: ${name}$" "$BREWFILE"
  else
    grep -qx "${type} '${name}'" "$BREWFILE"
  fi
}

# Insert a line into the Brewfile in the correct section, alphabetically sorted.
# Args: type ("tap"|"brew"|"cask"|"mas"), name [, id (required for mas)]
_brewfile_insert() {
  local type="$1" name="$2"
  local line

  if [[ "$type" == "mas" ]]; then
    local id="$3"
    line="mas '${name}', id: ${id}"
  else
    line="${type} '${name}'"
  fi

  local section_pattern="^${type} '"
  local last_section_line
  last_section_line="$(grep -n "$section_pattern" "$BREWFILE" 2>/dev/null | tail -1 | cut -d: -f1)"

  if [[ -z "$last_section_line" ]]; then
    # Section doesn't exist — append with blank line separator
    echo "" >> "$BREWFILE"
    echo "$line" >> "$BREWFILE"
  else
    # Find correct alphabetical position within section
    local inserted=false
    local tmp
    tmp="$(mktemp)"
    while IFS= read -r existing; do
      if [[ "$inserted" == false ]] && [[ "$existing" =~ ^${type}\ \' ]]; then
        local existing_name
        existing_name="$(echo "$existing" | awk -F"'" '{print $2}')"
        if [[ "$name" < "$existing_name" ]]; then
          echo "$line" >> "$tmp"
          inserted=true
        fi
      fi
      echo "$existing" >> "$tmp"
    done < "$BREWFILE"

    if [[ "$inserted" == false ]]; then
      # Append after the last entry in the section
      sed -i '' "${last_section_line}a\\
${line}
" "$BREWFILE"
    else
      mv "$tmp" "$BREWFILE"
    fi
    rm -f "$tmp"
  fi

  log_success "Added $line to Brewfile"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/lib/brewfile.bats`
Expected: All 18 tests PASS

- [ ] **Step 5: Commit**

```bash
git add script/lib/brewfile.sh test/lib/brewfile.bats
git commit -m "Add lib/brewfile.sh with Brewfile parsing and sorted insertion"
```

---

### Task 4: Create lib/cask-detect.sh with tests

**Files:**
- Create: `test/lib/cask-detect.bats`
- Create: `script/lib/cask-detect.sh`

- [ ] **Step 1: Write failing tests**

Create `test/lib/cask-detect.bats`:

```bash
#!/usr/bin/env bats

setup() {
  load '../test_helper'
  source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
}

# --- _cask_app_artifacts ---

@test "_cask_app_artifacts extracts app paths from cask JSON" {
  run _cask_app_artifacts <<< '{"casks":[{"token":"slack","artifacts":[{"app":["Slack.app"]},{"zap":[]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "Slack.app" ]
}

@test "_cask_app_artifacts returns empty for cask with no app artifacts" {
  run _cask_app_artifacts <<< '{"casks":[{"token":"some-cli","artifacts":[{"binary":["/usr/local/bin/foo"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

@test "_cask_app_artifacts handles multiple app entries" {
  run _cask_app_artifacts <<< '{"casks":[{"token":"multi","artifacts":[{"app":["App1.app","App2.app"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "App1.app" ]
  [ "${lines[1]}" = "App2.app" ]
}

# --- _cask_uninstall_artifacts ---

@test "_cask_uninstall_artifacts extracts delete paths" {
  run _cask_uninstall_artifacts <<< '{"casks":[{"token":"foo","artifacts":[{"uninstall":[{"delete":["/Applications/Foo.app","/Library/Foo"]}]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "/Applications/Foo.app" ]
  [ "${lines[1]}" = "/Library/Foo" ]
}

@test "_cask_uninstall_artifacts returns empty when no uninstall artifacts" {
  run _cask_uninstall_artifacts <<< '{"casks":[{"token":"bar","artifacts":[{"app":["Bar.app"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}

# --- _cask_pkgutil_ids ---

@test "_cask_pkgutil_ids extracts pkgutil receipt IDs" {
  run _cask_pkgutil_ids <<< '{"casks":[{"token":"baz","artifacts":[{"uninstall":[{"pkgutil":"com.example.baz"}]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "com.example.baz" ]
}

@test "_cask_pkgutil_ids handles array of pkgutil IDs" {
  run _cask_pkgutil_ids <<< '{"casks":[{"token":"baz","artifacts":[{"uninstall":[{"pkgutil":["com.example.a","com.example.b"]}]}]}]}'
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "com.example.a" ]
  [ "${lines[1]}" = "com.example.b" ]
}

@test "_cask_pkgutil_ids returns empty when no pkgutil artifacts" {
  run _cask_pkgutil_ids <<< '{"casks":[{"token":"bar","artifacts":[{"app":["Bar.app"]}]}]}'
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 0 ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats test/lib/cask-detect.bats`
Expected: All tests FAIL (source file not found)

- [ ] **Step 3: Write implementation**

Create `script/lib/cask-detect.sh`:

```bash
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/lib/cask-detect.bats`
Expected: All 8 tests PASS

- [ ] **Step 5: Commit**

```bash
git add script/lib/cask-detect.sh test/lib/cask-detect.bats
git commit -m "Add lib/cask-detect.sh with jq-based cask artifact detection"
```

---

### Task 5: Create lib/drift.sh with tests

**Files:**
- Create: `test/lib/drift.bats`
- Create: `script/lib/drift.sh`

This library depends on brewfile.sh and skip-lists.sh (both already created).

- [ ] **Step 1: Write failing tests**

Create `test/lib/drift.bats`:

```bash
#!/usr/bin/env bats

setup() {
  load '../test_helper'

  # Source dependencies first (drift.sh also sources them via guard)
  source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
  source "$DOTFILES_ROOT/script/lib/brewfile.sh"
  source "$DOTFILES_ROOT/script/lib/drift.sh"

  copy_fixture "Brewfile.full"

  # Default: no skip lists, no ignore file
  unset HOMEBREW_BUNDLE_CASK_SKIP
  unset HOMEBREW_BUNDLE_MAS_SKIP
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/nonexistent"
}

# --- _collect_drift_formulae ---

@test "_collect_drift_formulae returns untracked formulae" {
  # Mock brew leaves to return some tracked and some untracked
  brew() { echo "git"; echo "jq"; echo "unknown-formula"; }
  export -f brew
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ "$output" = "unknown-formula" ]
}

@test "_collect_drift_formulae returns empty when all tracked" {
  brew() { echo "git"; echo "jq"; }
  export -f brew
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_collect_drift_formulae returns empty when brew fails" {
  brew() { return 1; }
  export -f brew
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "_collect_drift_formulae filters ignored packages" {
  brew() { echo "unknown-formula"; }
  export -f brew
  export AUDIT_IGNORE_FILE="$BATS_TEST_TMPDIR/ignore"
  echo "unknown-formula" > "$AUDIT_IGNORE_FILE"
  run _collect_drift_formulae
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _collect_drift_casks ---

@test "_collect_drift_casks returns untracked casks" {
  brew() {
    case "$1" in
      list) echo "1password"; echo "firefox"; echo "unknown-cask" ;;
    esac
  }
  export -f brew
  run _collect_drift_casks
  [ "$status" -eq 0 ]
  [ "$output" = "unknown-cask" ]
}

@test "_collect_drift_casks filters skipped casks" {
  export HOMEBREW_BUNDLE_CASK_SKIP="unknown-cask"
  brew() {
    case "$1" in
      list) echo "unknown-cask" ;;
    esac
  }
  export -f brew
  run _collect_drift_casks
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _collect_drift_taps ---

@test "_collect_drift_taps returns untracked taps" {
  brew() {
    echo "homebrew/bundle"
    echo "homebrew/cask-fonts"
    echo "nikitabobko/tap"
    echo "some/unknown-tap"
  }
  export -f brew
  run _collect_drift_taps
  [ "$status" -eq 0 ]
  [ "$output" = "some/unknown-tap" ]
}

@test "_collect_drift_taps skips implicit taps" {
  brew() {
    echo "homebrew/core"
    echo "homebrew/cask"
    echo "homebrew/bundle"
  }
  export -f brew
  run _collect_drift_taps
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _collect_drift_mas ---

@test "_collect_drift_mas returns untracked mas apps" {
  mas() { echo "409183694 Keynote (14.0)"; echo "999999999 Unknown App (1.0)"; }
  export -f mas
  run _collect_drift_mas
  [ "$status" -eq 0 ]
  [ "$output" = "999999999 Unknown App" ]
}

@test "_collect_drift_mas filters skipped mas ids" {
  export HOMEBREW_BUNDLE_MAS_SKIP="999999999"
  mas() { echo "999999999 Unknown App (1.0)"; }
  export -f mas
  run _collect_drift_mas
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- _count_total_drift ---

@test "_count_total_drift sums all drift categories" {
  brew() {
    case "$1" in
      leaves) echo "unknown-formula" ;;
      list)   echo "unknown-cask" ;;
      tap)    echo "homebrew/bundle" ;;
    esac
  }
  export -f brew
  mas() { return 1; }
  export -f mas
  run _count_total_drift
  [ "$status" -eq 0 ]
  [ "$output" = "2" ]
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats test/lib/drift.bats`
Expected: All tests FAIL (source file not found)

- [ ] **Step 3: Write implementation**

Create `script/lib/drift.sh`:

```bash
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
    _is_mas_skipped "$mas_id" && continue
    _is_audit_ignored "$mas_id" && continue
    _brewfile_contains "mas" "$mas_id" || echo "$mas_id $mas_name"
  done <<< "$mas_list"
}

# Count total drift across all categories.
# Prints integer count to stdout.
_count_total_drift() {
  local count=0
  local line
  while IFS= read -r line; do
    [[ -n "$line" ]] && count=$((count + 1))
  done < <(_collect_drift_taps)
  while IFS= read -r line; do
    [[ -n "$line" ]] && count=$((count + 1))
  done < <(_collect_drift_formulae)
  while IFS= read -r line; do
    [[ -n "$line" ]] && count=$((count + 1))
  done < <(_collect_drift_casks)
  while IFS= read -r line; do
    [[ -n "$line" ]] && count=$((count + 1))
  done < <(_collect_drift_mas)
  echo "$count"
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats test/lib/drift.bats`
Expected: All 11 tests PASS

- [ ] **Step 5: Run full test suite**

Run: `bats test/`
Expected: All tests across all files PASS (skip-lists + brewfile + cask-detect + drift)

- [ ] **Step 6: Commit**

```bash
git add script/lib/drift.sh test/lib/drift.bats
git commit -m "Add lib/drift.sh with drift collection for taps, formulae, casks, mas"
```

---

### Task 6: Refactor brew-health to use new libraries

**Files:**
- Modify: `script/brew-health:14-17` (add source lines)
- Modify: `script/brew-health:129-134` (replace tap parsing)
- Modify: `script/brew-health:173-192` (replace Python with jq)
- Modify: `script/brew-health:212-234` (replace Python with _find_orphaned_cask_apps)

Simplest consumer — only uses brewfile.sh and cask-detect.sh.

- [ ] **Step 1: Add source lines to brew-health**

After the existing `source "$DOTFILES_ROOT/script/lib/output.sh"` line (line 17), add:

```bash
# shellcheck source=lib/brewfile.sh
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
# shellcheck source=lib/cask-detect.sh
source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
```

Set BREWFILE (already defined on line 14, no change needed).

- [ ] **Step 2: Replace _check_obsolete_taps Brewfile parsing**

In `_check_obsolete_taps()`, replace lines 130-135:

```bash
  local expected_taps=()
  if [[ -f "$BREWFILE" ]]; then
    while IFS= read -r _tap_line; do
      expected_taps+=("$_tap_line")
    done < <(grep "^tap " "$BREWFILE" | sed "s/tap '\\(.*\\)'/\\1/")
  fi
```

With:

```bash
  local expected_taps=()
  if [[ -f "$BREWFILE" ]]; then
    mapfile -t expected_taps < <(_brewfile_list_section "tap")
  fi
```

- [ ] **Step 3: Replace _check_disabled_formulae Python with jq**

In `_check_disabled_formulae()`, replace lines 182-192:

```bash
  local disabled
  disabled="$(echo "$json" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for f in data.get('formulae', []):
    if f.get('disabled', False):
        name = f['name']
        msg = f.get('disable_reason', 'no reason given')
        date = f.get('disable_date', 'unknown date')
        print(f'{name} (disabled {date}: {msg})')
" 2>/dev/null || true)"
```

With:

```bash
  local disabled
  disabled="$(echo "$json" | jq -r '
    .formulae[]? |
    select(.disabled == true) |
    "\(.name) (disabled \(.disable_date // "unknown date"): \(.disable_reason // "no reason given"))"
  ' 2>/dev/null || true)"
```

- [ ] **Step 4: Replace _check_orphaned_casks with _find_orphaned_cask_apps**

Replace the entire body of `_check_orphaned_casks()` (lines 212-248) with:

```bash
_check_orphaned_casks() {
  local orphaned
  orphaned="$(_find_orphaned_cask_apps 2>/dev/null || true)"

  if [[ -z "$orphaned" ]]; then
    _check_pass "Cask app artifacts present"
    return 0
  fi

  _check_fail "Orphaned cask metadata"
  while IFS= read -r entry; do
    local cask="${entry%%|*}" app="${entry#*|}"
    _check_detail "$cask — /Applications/$app missing"
    _check_detail "  run: brew uninstall --cask $cask"
  done <<< "$orphaned"
  return 1
}
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n script/brew-health`
Expected: No syntax errors

- [ ] **Step 6: Commit**

```bash
git add script/brew-health
git commit -m "Refactor brew-health to use shared brewfile.sh and cask-detect.sh"
```

---

### Task 7: Refactor brew-skip-detect to use new libraries

**Files:**
- Modify: `script/brew-skip-detect:14-19` (add source lines)
- Modify: `script/brew-skip-detect:24-28` (replace Brewfile cask parsing)
- Modify: `script/brew-skip-detect:52-63` (replace skip-list check)
- Modify: `script/brew-skip-detect:73-147` (replace detection strategies with _is_cask_preinstalled)

- [ ] **Step 1: Add source lines to brew-skip-detect**

After the existing `source "$DOTFILES_ROOT/script/lib/output.sh"` line (line 15), add:

```bash
# shellcheck source=lib/brewfile.sh
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
# shellcheck source=lib/skip-lists.sh
source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
# shellcheck source=lib/cask-detect.sh
source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
```

Also add `BREWFILE="$DOTFILES_ROOT/Brewfile"` after `DOTFILES_ROOT` is set (line 12).

- [ ] **Step 2: Replace Brewfile cask collection**

Replace lines 24-28:

```bash
# Collect cask tokens from Brewfile
brewfile_casks=()
while IFS= read -r cask; do
  brewfile_casks+=("$cask")
done < <(grep "^cask '" "$DOTFILES_ROOT/Brewfile" | awk -F"'" '{print $2}')
```

With:

```bash
# Collect cask tokens from Brewfile
brewfile_casks=()
mapfile -t brewfile_casks < <(_brewfile_list_section "cask")
```

- [ ] **Step 3: Replace skip-list filtering**

Replace lines 52-63:

```bash
if [ -n "${HOMEBREW_BUNDLE_CASK_SKIP:-}" ]; then
  filtered_casks=()
  for cask in "${unmanaged_casks[@]}"; do
    if ! echo " $HOMEBREW_BUNDLE_CASK_SKIP " | grep -q " $cask "; then
      filtered_casks+=("$cask")
    fi
  done
  if [ ${#filtered_casks[@]} -eq 0 ]; then
    substep_log_info "skipping casks installed outside Homebrew"
    return 0
  fi
  unmanaged_casks=("${filtered_casks[@]}")
fi
```

With:

```bash
if [ -n "${HOMEBREW_BUNDLE_CASK_SKIP:-}" ]; then
  filtered_casks=()
  for cask in "${unmanaged_casks[@]}"; do
    _is_cask_skipped "$cask" || filtered_casks+=("$cask")
  done
  if [ ${#filtered_casks[@]} -eq 0 ]; then
    substep_log_info "skipping casks installed outside Homebrew"
    return 0
  fi
  unmanaged_casks=("${filtered_casks[@]}")
fi
```

- [ ] **Step 4: Replace detection strategies with _is_cask_preinstalled**

Replace lines 73-147 (the entire `for cask in "${unmanaged_casks[@]}"` loop including all three strategies):

```bash
for cask in "${unmanaged_casks[@]}"; do
  # Ask brew for this cask's artifact metadata
  json=$(brew info --cask --json=v2 "$cask" 2>/dev/null || true)
  [ -z "$json" ] && continue

  found_app=""

  # Strategy 1: Check 'app' artifacts in /Applications
  while IFS= read -r app; do
    ...
  done < <(echo "$json" | python3 -c "..." 2>/dev/null)

  # Strategy 2: ...
  # Strategy 3: ...

  if [ -n "$found_app" ]; then
    skip_casks+=("$cask")
    skip_details+=("$cask ($found_app)")
  fi
done
```

With:

```bash
for cask in "${unmanaged_casks[@]}"; do
  if _is_cask_preinstalled "$cask"; then
    skip_casks+=("$cask")
    skip_details+=("$cask ($_DETECTED_APP_PATH)")
  fi
done
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n script/brew-skip-detect`
Expected: No syntax errors

- [ ] **Step 6: Commit**

```bash
git add script/brew-skip-detect
git commit -m "Refactor brew-skip-detect to use shared libraries"
```

---

### Task 8: Refactor brew-audit to use new libraries

**Files:**
- Modify: `script/brew-audit:15-16` (add source lines)
- Modify: `script/brew-audit:29-42` (delete helper functions replaced by libraries)
- Modify: `script/brew-audit:97-182` (delete _add_to_brewfile and _add_mas_to_brewfile)
- Modify: `script/brew-audit:279-338` (replace drift collection)
- Modify: various call sites to use new function names

This is the largest refactor — many deletions, many call site updates.

**Note on spinner cleanup:** The spec mentions replacing manual `spinner_start`/`spinner_stop` calls with `run_with_substep_spinner`. This is intentionally NOT done here. brew-audit uses top-level `spinner_start`/`spinner_stop` (2-space indent), while `run_with_substep_spinner` uses `substep_start`/`substep_stop` (6-space indent). Switching would change the visual output, violating the "identical behavior" criterion. The manual spinner patterns in brew-audit stay as-is — they're not cross-file duplication (all in one file), and the visual difference matters.

- [ ] **Step 1: Add source lines to brew-audit**

After the existing `source "$DOTFILES_ROOT/script/lib/output.sh"` line (line 16), add:

```bash
# shellcheck source=lib/brewfile.sh
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
# shellcheck source=lib/skip-lists.sh
source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
# shellcheck source=lib/drift.sh
source "$DOTFILES_ROOT/script/lib/drift.sh"
# shellcheck source=lib/cask-detect.sh
source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
```

- [ ] **Step 2: Delete duplicated helper functions**

Delete `_is_ignored()` (lines 29-32), `_is_in_cask_skip()` (lines 34-37), and `_is_in_mas_skip()` (lines 39-42) — all replaced by skip-lists.sh.

- [ ] **Step 3: Delete _add_to_brewfile and _add_mas_to_brewfile**

Delete `_add_to_brewfile()` (lines 97-139) and `_add_mas_to_brewfile()` (lines 143-182) — both replaced by `_brewfile_insert()` from brewfile.sh.

- [ ] **Step 4: Update all _is_ignored / _is_in_cask_skip / _is_in_mas_skip call sites**

Replace across the file:
- `_is_ignored` → `_is_audit_ignored`
- `_is_in_cask_skip` → `_is_cask_skipped`
- `_is_in_mas_skip` → `_is_mas_skipped`

Affected lines (approximate, after deletions shift them):
- Line 290: `_is_ignored "$_tap"` → `_is_audit_ignored "$_tap"`
- Line 312: `_is_ignored "$leaf"` → `_is_audit_ignored "$leaf"`
- Line 319: `_is_in_cask_skip "$cask"` → `_is_cask_skipped "$cask"`
- Line 320: `_is_ignored "$cask"` → `_is_audit_ignored "$cask"`
- Line 332: `_is_in_mas_skip "$_mas_id"` → `_is_mas_skipped "$_mas_id"`
- Line 333: `_is_ignored "$_mas_id"` → `_is_audit_ignored "$_mas_id"`
- Line 402: `_is_ignored "$candidate"` → `_is_audit_ignored "$candidate"`

- [ ] **Step 5: Replace drift collection (Phase 1) with library calls**

Replace lines 280-338 (the four drift collection loops) with:

```bash
# Collect drift using shared library
mapfile -t drift_taps < <(_collect_drift_taps)
mapfile -t drift_formulae < <(_collect_drift_formulae)
mapfile -t drift_casks < <(_collect_drift_casks)

# mas drift needs special handling — library returns "id name" pairs,
# but brew-audit stores "id:name" pairs for display
drift_mas=()
if command -v mas &>/dev/null; then
  while IFS= read -r _drift_line; do
    [[ -z "$_drift_line" ]] && continue
    local _mas_id="${_drift_line%% *}"
    local _mas_name="${_drift_line#* }"
    drift_mas+=("${_mas_id}:${_mas_name}")
  done < <(_collect_drift_mas)
fi
```

Also delete the `_expected_taps` collection loop (lines 280-283) since `_collect_drift_taps` handles this internally.

- [ ] **Step 6: Update all _add_to_brewfile / _add_mas_to_brewfile call sites**

Replace every call:
- `_add_to_brewfile "tap" "$t"` → `_brewfile_insert "tap" "$t"`
- `_add_to_brewfile "brew" "$f"` → `_brewfile_insert "brew" "$f"`
- `_add_to_brewfile "cask" "$c"` → `_brewfile_insert "cask" "$c"`
- `_add_mas_to_brewfile "$_mname" "$_mid"` → `_brewfile_insert "mas" "$_mname" "$_mid"`

Affected call sites (search for `_add_to_brewfile` and `_add_mas_to_brewfile`):
- Line ~467: `_add_to_brewfile "tap" "$t"` → `_brewfile_insert "tap" "$t"`
- Line ~468: `_add_to_brewfile "brew" "$f"` → `_brewfile_insert "brew" "$f"`
- Line ~469: `_add_to_brewfile "cask" "$c"` → `_brewfile_insert "cask" "$c"`
- Line ~471: `_add_mas_to_brewfile "${m#*:}" "${m%%:*}"` → `_brewfile_insert "mas" "${m#*:}" "${m%%:*}"`
- Line ~486: `_add_to_brewfile "tap" "$t"` → `_brewfile_insert "tap" "$t"`
- Line ~499: `_add_to_brewfile "brew" "$f"` → `_brewfile_insert "brew" "$f"`
- Line ~512: `_add_to_brewfile "cask" "$c"` → `_brewfile_insert "cask" "$c"`
- Line ~527: `_add_mas_to_brewfile "$_mname" "$_mid"` → `_brewfile_insert "mas" "$_mname" "$_mid"`
- Line ~541: `_add_to_brewfile "cask" "${adoptable_casks[$i]}"` → `_brewfile_insert "cask" "${adoptable_casks[$i]}"`

Also update `_adopt_cask` (line ~255):
- `_add_to_brewfile "cask" "$cask"` → `_brewfile_insert "cask" "$cask"`

- [ ] **Step 7: Verify syntax**

Run: `bash -n script/brew-audit`
Expected: No syntax errors

- [ ] **Step 8: Commit**

```bash
git add script/brew-audit
git commit -m "Refactor brew-audit to use shared libraries, remove duplicated helpers"
```

---

### Task 9: Refactor bootstrap to use new libraries and decompose Phase 4

**Files:**
- Modify: `script/bootstrap:13-14` (add source lines)
- Modify: `script/bootstrap:340-606` (decompose Phase 4 into functions)
- Modify: `script/bootstrap:465-564` (replace drift detection with library call)

This is the most complex refactor — Phase 4 needs structural decomposition.

- [ ] **Step 1: Add source lines to bootstrap**

After the existing `source "$DOTFILES_ROOT/script/lib/output.sh"` line (line 14), add:

```bash
# shellcheck source=lib/brewfile.sh
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
# shellcheck source=lib/skip-lists.sh
source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
# shellcheck source=lib/drift.sh
source "$DOTFILES_ROOT/script/lib/drift.sh"

BREWFILE="$DOTFILES_ROOT/Brewfile"
```

- [ ] **Step 2: Extract _phase4_ensure_homebrew function**

Add the following function before Phase 4 (before line 340). Extract from lines 358-381:

```bash
_phase4_ensure_homebrew() {
  if ! command -v brew &>/dev/null; then
    if $VERBOSE; then
      log_info "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      log_success "Homebrew installed"
    else
      run_with_substep_spinner "installing homebrew" "$LOGFILE" \
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Ensure brew is on PATH for the rest of this script
    if [[ -x "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x "/usr/local/bin/brew" ]]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  else
    if ! $VERBOSE; then
      substep_log_success "homebrew ready"
    else
      log_skip "Homebrew already installed"
    fi
  fi
}
```

- [ ] **Step 3: Extract _phase4_update_and_bundle function**

Add this function. Extract from lines 391-463:

```bash
_phase4_update_and_bundle() {
  if $VERBOSE; then
    log_info "brew update..."
    brew update 2>&1 | tee -a "$LOGFILE"
    log_success "brew update"

    log_info "brew upgrade..."
    if brew upgrade 2>&1 | tee -a "$LOGFILE"; then
      log_success "brew upgrade"
    else
      _upgrade_tail="$(tail -n 30 "$LOGFILE")"
      if echo "$_upgrade_tail" | grep -qE 'has been disabled|is not there|Permission denied|locked'; then
        log_error "brew upgrade (see ${LOGFILE##*/} for details)"
      else
        log_warn "brew upgrade (some packages skipped)"
      fi
    fi

    log_info "brew bundle..."
    _log_lines_before=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)
    brew bundle --file="$DOTFILES_ROOT/Brewfile" 2>&1 | tee -a "$LOGFILE"
    log_success "brew bundle"
  else
    run_with_substep_spinner "brew update" "$LOGFILE" \
      brew update

    substep_start "brew upgrade"
    if brew upgrade >> "$LOGFILE" 2>&1; then
      substep_stop ok "brew upgrade"
    else
      _upgrade_tail="$(tail -n 30 "$LOGFILE")"
      if echo "$_upgrade_tail" | grep -qE 'has been disabled|is not there|Permission denied|locked'; then
        substep_stop fail "brew upgrade (errors in ${LOGFILE##*/})"
      else
        substep_stop warn "brew upgrade (some packages skipped)"
      fi
    fi

    _log_lines_before=$(wc -l < "$LOGFILE" 2>/dev/null || echo 0)
    run_with_substep_streaming_spinner "brew bundle" "$LOGFILE" \
      brew bundle --file="$DOTFILES_ROOT/Brewfile"
  fi

  # Build brew bundle summary from log
  _brew_installed=0
  _brew_upgraded=0
  _brew_using=0
  while IFS= read -r _line; do
    case "$_line" in
      Installing\ *) _brew_installed=$((_brew_installed + 1)) ;;
      Upgrading\ *)  _brew_upgraded=$((_brew_upgraded + 1)) ;;
      Using\ *)      _brew_using=$((_brew_using + 1)) ;;
    esac
  done < <(tail -n +"$((_log_lines_before + 1))" "$LOGFILE")

  _brew_summary=""
  if (( _brew_installed > 0 )); then
    _brew_summary="${_brew_installed} installed"
  fi
  if (( _brew_upgraded > 0 )); then
    [[ -n "$_brew_summary" ]] && _brew_summary+=", "
    _brew_summary+="${_brew_upgraded} upgraded"
  fi
  if [[ -z "$_brew_summary" ]]; then
    _brew_summary="all up to date"
  fi

  if $VERBOSE; then
    log_success "$_brew_summary"
  fi
}
```

- [ ] **Step 4: Extract _phase4_detect_drift function**

Replace lines 465-564 (the drift check and its output) with this function:

```bash
_phase4_detect_drift() {
  if ! $VERBOSE; then
    substep_start "drift check"
  fi

  local _audit_count
  _audit_count="$(_count_total_drift 2>/dev/null)" || _audit_count=""

  if [[ -z "$_audit_count" ]]; then
    _ACTIONABLE_WARNINGS+=("drift check skipped: brew query failed (Homebrew may be broken)")
    if $VERBOSE; then
      log_warn "drift check skipped: brew query failed (Homebrew may be broken)"
    else
      substep_stop warn "drift check (skipped — brew query failed)"
    fi
  elif [[ "$_audit_count" -gt 0 ]]; then
    _ACTIONABLE_WARNINGS+=("$_audit_count packages not in Brewfile — run ${_BOLD}script/brew-audit${_RST}")
    if $VERBOSE; then
      log_warn "$_audit_count packages not in Brewfile — run ${_BOLD}script/brew-audit${_RST}"
    else
      substep_stop warn "drift check ($_audit_count untracked)"
    fi
  else
    if ! $VERBOSE; then
      substep_stop ok "drift check"
    fi
  fi
}
```

- [ ] **Step 5: Extract _phase4_check_vulnerabilities function**

Extract lines 566-601 into a function (copy verbatim, no library changes needed):

```bash
_phase4_check_vulnerabilities() {
  if ! command -v brew-vulns &>/dev/null; then
    return 0
  fi

  if ! $VERBOSE; then
    substep_start "vuln check"
  fi

  _vuln_count=0
  _vuln_output=""

  if command -v gtimeout &>/dev/null; then
    _vuln_output="$(gtimeout 15 brew vulns --severity high 2>/dev/null)" || true
  else
    _vuln_output="$(brew vulns --severity high 2>/dev/null)" || true
  fi

  if [[ -n "$_vuln_output" ]]; then
    _vuln_count="$(echo "$_vuln_output" | grep -cE '^[a-z].*\(' || true)"
  fi

  if [[ $_vuln_count -gt 0 ]]; then
    _ACTIONABLE_WARNINGS+=("$_vuln_count vulnerable packages — run ${_BOLD}script/brew-health${_RST}")
  fi

  if $VERBOSE; then
    if [[ $_vuln_count -gt 0 ]]; then
      log_warn "$_vuln_count vulnerable packages — run ${_BOLD}script/brew-health${_RST}"
    fi
  else
    if [[ $_vuln_count -gt 0 ]]; then
      substep_stop warn "vuln check ($_vuln_count vulnerable)"
    else
      substep_stop ok "vuln check"
    fi
  fi
}
```

- [ ] **Step 6: Rewrite Phase 4 body as orchestration**

Replace the entire Phase 4 `else` block (lines 348-606) with:

```bash
else
  _phase_timer_start "Installing Software"

  if $VERBOSE; then
    log_phase "4/5" "Installing Software"
  else
    phase_start "4/5" "Installing Software"
    phase_end_deferred
  fi

  _phase4_ensure_homebrew

  # Cask skip detection — save/restore shell options since brew-skip-detect uses set -euo pipefail
  if [[ -f "$DOTFILES_ROOT/script/brew-skip-detect" ]]; then
    _saved_opts=$(set +o)
    source "$DOTFILES_ROOT/script/brew-skip-detect"
    eval "$_saved_opts"
  fi

  _phase4_update_and_bundle
  _phase4_detect_drift
  _phase4_check_vulnerabilities

  if ! $VERBOSE; then
    phase_resolve ok "$_brew_summary"
  fi
fi
```

- [ ] **Step 7: Verify syntax**

Run: `bash -n script/bootstrap`
Expected: No syntax errors

- [ ] **Step 8: Commit**

```bash
git add script/bootstrap
git commit -m "Refactor bootstrap Phase 4 into focused functions using shared libraries"
```

---

### Task 10: Final verification

**Files:** None modified — verification only.

- [ ] **Step 1: Run full test suite**

Run: `bats test/`
Expected: All tests pass across all 4 test files

- [ ] **Step 2: Verify no python3 -c calls remain**

Run: `grep -rn "python3 -c" script/`
Expected: Zero matches

- [ ] **Step 3: Verify all libraries have source guards**

Run: `grep -l "_LOADED" script/lib/*.sh`
Expected: All 5 files listed (output.sh, brewfile.sh, skip-lists.sh, drift.sh, cask-detect.sh)

- [ ] **Step 4: Verify no duplicated Brewfile parsing**

Run: `grep -rn "grep.*\^tap.*sed" script/bootstrap script/brew-audit script/brew-health script/brew-skip-detect`
Expected: Zero matches (all use `_brewfile_list_section` now)

Run: `grep -rn 'grep -qx.*brew.*\$' script/bootstrap script/brew-audit`
Expected: Zero matches (all use `_brewfile_contains` now)

- [ ] **Step 5: Verify no duplicated skip-list checks**

Run: `grep -rn 'HOMEBREW_BUNDLE_CASK_SKIP' script/bootstrap script/brew-audit`
Expected: Zero matches in these files (all use `_is_cask_skipped` from skip-lists.sh)

- [ ] **Step 6: Line count check**

Run: `wc -l script/bootstrap script/brew-audit script/brew-health script/brew-skip-detect`
Expected: No orchestrator script exceeds ~400 lines

- [ ] **Step 7: Syntax check all scripts**

Run: `bash -n script/bootstrap && bash -n script/brew-audit && bash -n script/brew-health && bash -n script/brew-skip-detect`
Expected: All pass with no errors

- [ ] **Step 8: Smoke test bootstrap dry run**

Run: `script/bootstrap --dry-run`
Expected: Dry run output matches pre-refactor behavior (preview of phases, no errors)

- [ ] **Step 9: Commit verification results (if any fixups were needed)**

If any fixes were made during verification, commit them:

```bash
git add -A
git commit -m "Fix issues found during post-refactor verification"
```
