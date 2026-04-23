# git-logme Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite `bin/git-logme` with robust identity discovery, convenience time filters, a compact default format, and a `--list` debugging flag.

**Architecture:** Full rewrite of a single file (`bin/git-logme`). Replaces fragile sed-based config parsing with `git config --get-regexp` for identity discovery. Adds BATS integration tests for the `--list` flag using `GIT_CONFIG_GLOBAL` to control identity resolution in isolation.

**Tech Stack:** Bash, git config, BATS (testing), shellcheck (automated PostToolUse hook)

**Spec:** `docs/superpowers/specs/2026-04-23-git-logme-redesign-design.md`

---

### Task 1: Rewrite bin/git-logme

**Files:**
- Modify: `bin/git-logme` (full replacement)

- [ ] **Step 1: Replace the entire file with the new implementation**

Replace the contents of `bin/git-logme` with:

```bash
#!/usr/bin/env bash
# git-logme — show your commits across all git identities. Run 'git logme -h'.

set -e

tmpfile=$(mktemp)
trap 'rm -f "$tmpfile"' EXIT

# -- helpers ---------------------------------------------------------

die()  { printf 'git-logme: %s\n' "$1" >&2; exit 1; }
warn() { printf 'git-logme: %s\n' "$1" >&2; }

# -- color detection ------------------------------------------------

if [ -n "$NO_COLOR" ] || [ ! -t 1 ]; then
  color_flag="--no-color"
else
  color_flag="--color"
fi

usage() {
  cat <<'EOF'
Usage: git logme [--list] [--today] [--week] [--month] [<git-log-options>]

Shows your commits across all your configured git identities.
Discovers user.name and user.email from your global, conditional
include, and repo-local git configs automatically.

Options:
  --list, -l              Show discovered identities and exit.
  --today, -t             Commits since midnight.
  --week, -w              Commits from the last 7 days.
  --month, -m             Commits from the last 30 days.
  -h                      Show this message.

All other arguments are forwarded to git log.

When no format flags are given, a compact format with relative
dates is used. Pass --oneline, --format, --pretty, --stat, etc.
to override.

Examples:
  git logme
  git logme --today
  git logme --week --stat
  git logme --list
  git logme --since="2025-01-01" --oneline
EOF
  exit 0
}

# -- identity discovery ----------------------------------------------

# Append identity<TAB>source pairs to $tmpfile.
# $1 = config file path, $2 = display label for source
extract_identities() {
  local file="$1" label="$2"
  [ -f "$file" ] || return 0
  local value
  while IFS= read -r value; do
    [ -n "$value" ] && printf '%s\t%s\n' "$value" "$label" >> "$tmpfile"
  done < <(git config --file "$file" --get-all user.name 2>/dev/null || true)
  while IFS= read -r value; do
    [ -n "$value" ] && printf '%s\t%s\n' "$value" "$label" >> "$tmpfile"
  done < <(git config --file "$file" --get-all user.email 2>/dev/null || true)
}

# -- parse flags -----------------------------------------------------

list_mode=false
since_filter=""
passthrough_args=()

while [ $# -gt 0 ]; do
  case "$1" in
    -h)              usage ;;
    --list|-l)       list_mode=true; shift ;;
    --today|-t)      since_filter="00:00"; shift ;;
    --week|-w)       since_filter="1 week ago"; shift ;;
    --month|-m)      since_filter="1 month ago"; shift ;;
    *)               passthrough_args+=("$1"); shift ;;
  esac
done

# -- collect identities ------------------------------------------------

# 1. Global config
global_config="$(git config --global --list --show-origin 2>/dev/null \
  | head -1 | cut -f1 | sed 's/^file://')" || true

if [ -n "$global_config" ] && [ -f "$global_config" ]; then
  global_label="${global_config/#$HOME/\~}"
  extract_identities "$global_config" "$global_label"

  # 2. All include / includeIf paths referenced in the global config.
  while IFS= read -r line; do
    path="${line#* }"
    path="${path/#\~/$HOME}"
    if [ -f "$path" ]; then
      path_label="${path/#$HOME/\~}"
      extract_identities "$path" "$path_label"
    fi
  done < <(git config --file "$global_config" --get-regexp '^include(if)?\..*\.path$' 2>/dev/null || true)
fi

# 3. Repo-local config (if inside a git repo)
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  extract_identities "$(git rev-parse --git-dir)/config" ".git/config"
fi

# -- deduplicate -------------------------------------------------------

identities=$(awk -F'\t' '!seen[$1]++' "$tmpfile")

if [ -z "$identities" ]; then
  die "no user identities found in git config"
fi

# -- list mode ---------------------------------------------------------

if $list_mode; then
  echo "git-logme: discovered identities:"
  while IFS=$'\t' read -r id source; do
    printf '  %-28s (%s)\n' "$id" "$source"
  done <<< "$identities"
  exit 0
fi

# -- detect user format flags ------------------------------------------

has_format_flag=false
for arg in "${passthrough_args[@]}"; do
  case "$arg" in
    --oneline|--pretty|--pretty=*|--format=*|--raw|--patch|-p|--stat|--stat=*|--graph)
      has_format_flag=true
      break
      ;;
  esac
done

# -- build git log command ---------------------------------------------

log_args=()

# Author filters (multiple --author flags are OR'd by git log)
while IFS=$'\t' read -r id _; do
  [ -n "$id" ] && log_args+=(--author="$id")
done <<< "$identities"

# Time filter
if [ -n "$since_filter" ]; then
  log_args+=(--since="$since_filter")
fi

# Default format when no format flags given
if ! $has_format_flag; then
  # shellcheck disable=SC2086
  log_args+=($color_flag "--format=%C(auto)%h %C(blue)%ad %C(auto)%s%C(dim)%d" --date=relative)
fi

# User pass-through args
log_args+=("${passthrough_args[@]}")

git log "${log_args[@]}"
```

- [ ] **Step 2: Verify shellcheck passes**

Run: `shellcheck bin/git-logme`
Expected: no errors (the PostToolUse hook also runs this automatically).

- [ ] **Step 3: Verify -h works**

Run: `bin/git-logme -h`
Expected: usage text prints and exits 0.

- [ ] **Step 4: Verify --list works**

Run: `bin/git-logme --list`
Expected: prints discovered identities with source file paths, then exits 0.

- [ ] **Step 5: Verify default format works**

Run: `bin/git-logme` (inside a repo with your commits)
Expected: compact format with short hash, relative date, subject, and decorations. No raw `git log` multiline format.

- [ ] **Step 6: Verify format pass-through works**

Run: `bin/git-logme --oneline`
Expected: standard `--oneline` format, NOT the default custom format.

- [ ] **Step 7: Verify time filters work**

Run: `bin/git-logme --today`
Expected: only commits since midnight today (may be empty if no commits today).

Run: `bin/git-logme --week`
Expected: only commits from the last 7 days.

- [ ] **Step 8: Verify args compose**

Run: `bin/git-logme --week --stat`
Expected: last 7 days of your commits with diffstat, using git's native format (--stat triggers format passthrough).

- [ ] **Step 9: Commit**

```bash
git add bin/git-logme
git commit -m "git-logme: rewrite with robust identity discovery and smarter defaults

Replaces sed-based config parsing with git config --get-regexp.
Adds --list for identity debugging, --today/--week/--month time
filters, and a compact default format with relative dates."
```

---

### Task 2: Add BATS tests for identity discovery

**Files:**
- Create: `script/test/bin/git-logme.bats`
- Create: `script/test/fixtures/gitconfig.logme-main`
- Create: `script/test/fixtures/gitconfig.logme-work`

- [ ] **Step 1: Create the main test fixture config**

Create `script/test/fixtures/gitconfig.logme-main` — a minimal gitconfig with one identity and an includeIf pointing to the work config:

```ini
[user]
	name = Test User
	email = test@example.com
```

Note: the includeIf is added dynamically in the test (because the path to the work fixture varies). This file provides the base identity.

- [ ] **Step 2: Create the work test fixture config**

Create `script/test/fixtures/gitconfig.logme-work`:

```ini
[user]
	name = Work User
	email = work@corp.com
```

- [ ] **Step 3: Write the BATS test file**

Create `script/test/bin/git-logme.bats`:

```bash
#!/usr/bin/env bats

setup() {
  load '../test_helper'
  LOGME="$DOTFILES_ROOT/bin/git-logme"

  # Create a temp gitconfig that includes the work fixture via includeIf
  TEMP_CONFIG="$BATS_TEST_TMPDIR/gitconfig"
  cp "$FIXTURES_DIR/gitconfig.logme-main" "$TEMP_CONFIG"

  # Append an include pointing to the work fixture
  printf '\n[include]\n\tpath = %s\n' "$FIXTURES_DIR/gitconfig.logme-work" >> "$TEMP_CONFIG"

  # Point git at our temp config instead of the real global
  export GIT_CONFIG_GLOBAL="$TEMP_CONFIG"

  # Init a bare repo so git rev-parse works (--list needs it for repo-local check)
  git init "$BATS_TEST_TMPDIR/repo" --quiet
  cd "$BATS_TEST_TMPDIR/repo"
}

@test "--list shows identities from global config" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Test User"* ]]
  [[ "${output}" == *"test@example.com"* ]]
}

@test "--list shows identities from included configs" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Work User"* ]]
  [[ "${output}" == *"work@corp.com"* ]]
}

@test "--list prints header line" {
  run "$LOGME" --list
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "git-logme: discovered identities:" ]]
}

@test "-l is an alias for --list" {
  run "$LOGME" -l
  [ "$status" -eq 0 ]
  [[ "${output}" == *"Test User"* ]]
}

@test "exits 1 with message when no identities found" {
  # Empty gitconfig with no user section
  printf '[core]\n\tbare = false\n' > "$TEMP_CONFIG"
  run "$LOGME" --list
  [ "$status" -eq 1 ]
  [[ "${output}" == *"no user identities found"* ]]
}

@test "-h prints usage and exits 0" {
  run "$LOGME" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git logme"* ]]
}
```

- [ ] **Step 4: Run the tests**

Run: `bats script/test/bin/git-logme.bats`
Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```bash
git add script/test/bin/git-logme.bats script/test/fixtures/gitconfig.logme-main script/test/fixtures/gitconfig.logme-work
git commit -m "test: add BATS tests for git-logme identity discovery and flags"
```

---

### Task 3: Smoke test all help text examples

This is manual verification — no code changes expected.

- [ ] **Step 1: Run each example from the help text**

```bash
# Basic usage — should show your commits in compact format
git logme

# Time filters
git logme --today
git logme --week

# Composing time filter with git log flag
git logme --week --stat

# Identity listing
git logme --list

# Full pass-through to git log
git logme --since="2025-01-01" --oneline
```

Verify for each:
- No errors or warnings on stderr
- Output format matches expectations (compact default vs. pass-through)
- `--list` shows at least one identity with a source file path
- Time filters narrow the output correctly

- [ ] **Step 2: Test NO_COLOR support**

```bash
NO_COLOR=1 git logme | head -5
```

Expected: no ANSI color codes in output.

- [ ] **Step 3: Test pipe behavior**

```bash
git logme | head -5
```

Expected: no ANSI color codes (stdout is not a tty when piped).

- [ ] **Step 4: Verify month flag**

```bash
git logme --month
```

Expected: commits from the last 30 days in compact format.
