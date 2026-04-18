# Homebrew Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the dotfiles bootstrap robust against Homebrew failures on any machine — new or years-old — by preventing fsmonitor lock issues, improving error detection, adding tap drift checks, and providing a standalone diagnostic tool.

**Architecture:** Six layers applied in order: prevention (fsmonitor override), detection (error hints), failure handling (smarter brew upgrade + honest drift queries), tap drift detection, inline drift reporting, and a `brew-health` diagnostic script that auto-runs on Phase 4 failure.

**Tech Stack:** Bash, Git config (`includeIf`), Homebrew CLI

**Spec:** `docs/superpowers/specs/2026-04-18-homebrew-hardening-design.md`

---

### Task 1: Prevention — fsmonitor override for Homebrew taps

**Files:**
- Create: `git/gitconfig-homebrew.symlink`
- Modify: `git/gitconfig.symlink:165` (append after last line)
- Modify: `AGENTS.md:57-61` (add gotcha entry)

- [ ] **Step 1: Create `git/gitconfig-homebrew.symlink`**

```gitconfig
[core]
        fsmonitor = false
```

This gets symlinked to `~/.gitconfig-homebrew` by bootstrap (standard `*.symlink` convention).

- [ ] **Step 2: Add `includeIf` blocks to `git/gitconfig.symlink`**

Append after line 165 (`defaultBranch = main`):

```gitconfig

# Homebrew runs git inside tap repos during `brew update`.
# With core.fsmonitor=true, git auto-starts fsmonitor daemons that can
# inherit Homebrew's update lock FD, permanently blocking future updates.
# Disable fsmonitor for Homebrew tap repos only.
[includeIf "gitdir:/opt/homebrew/Library/Taps/"]
        path = ~/.gitconfig-homebrew

[includeIf "gitdir:/usr/local/Homebrew/Library/Taps/"]
        path = ~/.gitconfig-homebrew
```

- [ ] **Step 3: Add gotcha to `AGENTS.md`**

In the `## Gotchas` section (after line 61, the "Private config" bullet), add:

```markdown
- **fsmonitor + Homebrew**: `core.fsmonitor=true` is enabled globally for performance, but disabled in Homebrew tap repos via `includeIf` + `git/gitconfig-homebrew.symlink`. Without this override, fsmonitor daemons inherit Homebrew's update lock FD and permanently block `brew update`. If you see `lockf: already locked` errors, check: `lsof "$(brew --prefix)/var/homebrew/locks/update"`.
```

- [ ] **Step 4: Verify the override works**

Run:
```bash
# Verify the symlink convention is recognized (check another .symlink file as reference)
ls -la ~/. | grep gitconfig

# Verify the includeIf path patterns are syntactically valid
git config --file git/gitconfig.symlink --list | grep includeIf
```

Expected: the `includeIf` entries appear in the config listing. The symlink won't exist until bootstrap runs, but the file itself is valid.

- [ ] **Step 5: Commit**

```bash
git add git/gitconfig-homebrew.symlink git/gitconfig.symlink AGENTS.md
git commit -m "Disable git fsmonitor in Homebrew tap repos

fsmonitor daemons started inside tap repos inherit Homebrew's update
lock FD, permanently blocking future brew update calls. The includeIf
override disables fsmonitor only for tap repos on both Apple Silicon
and Intel Homebrew paths."
```

---

### Task 2: Detection — add Homebrew error hint patterns

**Files:**
- Modify: `script/lib/output.sh:607-621` (add new patterns before the npm pattern)

- [ ] **Step 1: Add four new error hint patterns to `_detect_error_hint()`**

In `script/lib/output.sh`, insert the following four blocks **before** the existing npm/EEXIST check (line 617). They go after the `"is unavailable"` / `"was renamed"` block (line 610) and before the `"Could not resolve host"` block (line 612). Actually — insert them after the final existing block (the npm one at line 617-620), just before the closing `}` on line 621. This keeps the existing patterns in their current order and adds the new ones at the end:

Insert before line 621 (`}`):

```bash

  if [[ "$text" == *"lockf:"* ]] && [[ "$text" == *"already locked"* ]]; then
    printf "Homebrew update lock is held by another process.\n        Run: lsof \"\$(brew --prefix)/var/homebrew/locks/update\" to find the holder."
    return
  fi

  if [[ "$text" == *"Another"*"brew update"*"already running"* ]]; then
    printf "Homebrew update lock is held by another process.\n        Run: lsof \"\$(brew --prefix)/var/homebrew/locks/update\" to find the holder."
    return
  fi

  if [[ "$text" == *"does not exist"* ]] && [[ "$text" == *"brew untap"* ]]; then
    printf "An obsolete tap is blocking brew update.\n        The error message above includes the untap command to fix it."
    return
  fi

  if [[ "$text" == *"has been disabled because"* ]]; then
    printf "A disabled formula is causing errors during upgrade.\n        Uninstall it: brew uninstall <formula>"
    return
  fi

  if [[ "$text" == *"It seems the App source"* ]] && [[ "$text" == *"is not there"* ]]; then
    printf "A cask has metadata but its app is missing.\n        Reinstall: brew reinstall --cask <cask> or uninstall: brew uninstall --cask <cask>"
    return
  fi
```

- [ ] **Step 2: Verify the function is syntactically valid**

Run:
```bash
bash -n script/lib/output.sh
```

Expected: no output (clean parse).

- [ ] **Step 3: Commit**

```bash
git add script/lib/output.sh
git commit -m "Add Homebrew-specific error hint patterns

Detect lock contention, obsolete taps, disabled formulae, and missing
cask app bundles. Each pattern prints the diagnostic command or fix."
```

---

### Task 3: Failure handling — smarter `brew upgrade` in bootstrap

**Files:**
- Modify: `script/bootstrap:387-394` (verbose path)
- Modify: `script/bootstrap:404-410` (non-verbose path)

- [ ] **Step 1: Replace the non-verbose `brew upgrade` block**

Replace lines 404-410 in `script/bootstrap`:

```bash
    # brew upgrade can "fail" (exit 1) when there's nothing to upgrade
    substep_start "brew upgrade"
    if brew upgrade >> "$LOGFILE" 2>&1; then
      substep_stop ok "brew upgrade"
    else
      substep_stop warn "brew upgrade (some packages skipped)"
    fi
```

With:

```bash
    # brew upgrade exits nonzero for both benign (nothing to upgrade) and real
    # failures (disabled formula, missing cask app, permissions). Inspect the
    # log to distinguish them.
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
```

- [ ] **Step 2: Add error handling to the verbose `brew upgrade` path**

Replace lines 392-394 in `script/bootstrap`:

```bash
    log_info "brew upgrade..."
    brew upgrade 2>&1 | tee -a "$LOGFILE"
    log_success "brew upgrade"
```

With:

```bash
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
```

- [ ] **Step 3: Verify syntax**

Run:
```bash
bash -n script/bootstrap
```

Expected: no output (clean parse).

- [ ] **Step 4: Commit**

```bash
git add script/bootstrap
git commit -m "Classify brew upgrade failures instead of blanket warning

Inspect log output for real failure patterns (disabled formula, missing
cask app, permissions, lock). Show red fail for real errors, yellow
warning for benign exit codes."
```

---

### Task 4: Failure handling — honest drift queries

**Files:**
- Modify: `script/bootstrap:482-492` (drift check loops)

- [ ] **Step 1: Replace the drift check formula loop**

Replace lines 482-487 in `script/bootstrap`:

```bash
  _audit_count=0
  _ignore_file="$HOME/.brew-audit-ignore"
  while IFS= read -r leaf; do
    [[ -f "$_ignore_file" ]] && grep -qx "$leaf" "$_ignore_file" 2>/dev/null && continue
    grep -qx "brew '$leaf'" "$DOTFILES_ROOT/Brewfile" || _audit_count=$((_audit_count + 1))
  done < <(brew leaves 2>/dev/null)
```

With:

```bash
  _audit_count=0
  _drift_names=()
  _ignore_file="$HOME/.brew-audit-ignore"
  _drift_skipped=false

  if _brew_leaves="$(brew leaves 2>&1)"; then
    while IFS= read -r leaf; do
      [[ -z "$leaf" ]] && continue
      [[ -f "$_ignore_file" ]] && grep -qx "$leaf" "$_ignore_file" 2>/dev/null && continue
      if ! grep -qx "brew '$leaf'" "$DOTFILES_ROOT/Brewfile"; then
        _audit_count=$((_audit_count + 1))
        _drift_names+=("$leaf")
      fi
    done <<< "$_brew_leaves"
  else
    _drift_skipped=true
  fi
```

- [ ] **Step 2: Replace the drift check cask loop**

Replace lines 488-492 in `script/bootstrap`:

```bash
  while IFS= read -r cask; do
    echo " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " | grep -q " $cask " && continue
    [[ -f "$_ignore_file" ]] && grep -qx "$cask" "$_ignore_file" 2>/dev/null && continue
    grep -qx "cask '$cask'" "$DOTFILES_ROOT/Brewfile" || _audit_count=$((_audit_count + 1))
  done < <(brew list --cask 2>/dev/null)
```

With:

```bash
  if _brew_casks="$(brew list --cask 2>&1)"; then
    while IFS= read -r cask; do
      [[ -z "$cask" ]] && continue
      echo " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " | grep -q " $cask " && continue
      [[ -f "$_ignore_file" ]] && grep -qx "$cask" "$_ignore_file" 2>/dev/null && continue
      if ! grep -qx "cask '$cask'" "$DOTFILES_ROOT/Brewfile"; then
        _audit_count=$((_audit_count + 1))
        _drift_names+=("$cask")
      fi
    done <<< "$_brew_casks"
  else
    _drift_skipped=true
  fi
```

- [ ] **Step 3: Update the drift result reporting**

Replace lines 494-496 in `script/bootstrap`:

```bash
  if [[ $_audit_count -gt 0 ]]; then
    _ACTIONABLE_WARNINGS+=("$_audit_count packages not in Brewfile — run script/brew-audit")
  fi
```

With:

```bash
  if $_drift_skipped; then
    _ACTIONABLE_WARNINGS+=("drift check skipped: brew query failed (Homebrew may be broken)")
  elif [[ $_audit_count -gt 0 ]]; then
    _ACTIONABLE_WARNINGS+=("$_audit_count packages not in Brewfile — run script/brew-audit")
  fi
```

- [ ] **Step 4: Verify syntax**

Run:
```bash
bash -n script/bootstrap
```

Expected: no output (clean parse).

- [ ] **Step 5: Commit**

```bash
git add script/bootstrap
git commit -m "Stop swallowing brew query failures in drift check

If brew leaves or brew list --cask fails, report 'drift check skipped'
instead of silently showing zero drift. Also collect drift names into
an array for inline reporting."
```

---

### Task 5: Tap drift detection — Brewfile taps + bootstrap + brew-audit

**Files:**
- Modify: `Brewfile:1-12` (add tap declarations before brew section)
- Modify: `script/bootstrap` (drift check section, after cask loop from Task 4)
- Modify: `script/brew-audit:48-91` (add `tap` type to `_add_to_brewfile`)
- Modify: `script/brew-audit:188-220` (add tap drift collection before formula drift)
- Modify: `script/brew-audit:279-367` (add tap drift to interactive review)

- [ ] **Step 1: Add tap declarations to Brewfile**

Insert after line 11 (closing `end`) and before line 13 (`brew 'atuin'`):

```ruby

tap 'homebrew/bundle'
tap 'stripe/stripe-cli'

```

This makes the Brewfile a complete declaration of taps, not just formulae and casks. The blank line after `end` and before the first `brew` should be preserved.

- [ ] **Step 2: Add tap drift loop to bootstrap**

In `script/bootstrap`, after the cask drift loop (the code from Task 4, Step 2), and before the drift result reporting (Task 4, Step 3), insert:

```bash
  # Collect expected taps from Brewfile
  if ! $_drift_skipped; then
    _expected_taps=()
    while IFS= read -r _tap_line; do
      _expected_taps+=("$_tap_line")
    done < <(grep "^tap " "$DOTFILES_ROOT/Brewfile" | sed "s/tap '\\(.*\\)'/\\1/")

    if _installed_taps="$(brew tap 2>&1)"; then
      while IFS= read -r _tap; do
        [[ -z "$_tap" ]] && continue
        # Skip implicit taps
        [[ "$_tap" == "homebrew/core" || "$_tap" == "homebrew/cask" ]] && continue
        [[ -f "$_ignore_file" ]] && grep -qx "$_tap" "$_ignore_file" 2>/dev/null && continue
        _is_expected=false
        for _t in "${_expected_taps[@]:-}"; do
          [[ "$_t" == "$_tap" ]] && { _is_expected=true; break; }
        done
        if ! $_is_expected; then
          _audit_count=$((_audit_count + 1))
          _drift_names+=("tap:$_tap")
        fi
      done <<< "$_installed_taps"
    else
      _drift_skipped=true
    fi
  fi
```

- [ ] **Step 3: Update `_add_to_brewfile` in `script/brew-audit` to handle `tap` type**

The existing `_add_to_brewfile` function at `script/brew-audit:49-91` already works generically — it uses the `type` argument to find the section pattern (`^${type} '`) and inserts alphabetically. The `tap` type will work as-is because:
- `grep -n "^tap '" "$BREWFILE"` finds the tap section
- Alphabetical insertion works the same way

No code change needed here — just verify it works in Step 6.

- [ ] **Step 4: Add tap drift collection to `script/brew-audit` Phase 1**

In `script/brew-audit`, insert before line 188 (`# Collect drifted formulae`) and after line 186 (`printf "\n  ${_BOLD}brew-audit${_RST}\n\n"`):

```bash
# Collect expected taps from Brewfile
_expected_taps=()
while IFS= read -r _tap_line; do
  _expected_taps+=("$_tap_line")
done < <(grep "^tap " "$BREWFILE" | sed "s/tap '\\(.*\\)'/\\1/")

# Collect drifted taps
drift_taps=()
while IFS= read -r _tap; do
  [[ -z "$_tap" ]] && continue
  [[ "$_tap" == "homebrew/core" || "$_tap" == "homebrew/cask" ]] && continue
  _is_ignored "$_tap" && continue
  _is_expected=false
  for _t in "${_expected_taps[@]:-}"; do
    [[ "$_t" == "$_tap" ]] && { _is_expected=true; break; }
  done
  if ! $_is_expected; then
    drift_taps+=("$_tap")
  fi
done < <(brew tap 2>/dev/null)

# Display tap drift
if [[ ${#drift_taps[@]} -gt 0 ]]; then
  printf "  Taps not in Brewfile (%d):\n" "${#drift_taps[@]}"
  for t in "${drift_taps[@]}"; do
    printf "    %s %s\n" "$_INFO" "$t"
  done
  printf "\n"
fi

```

- [ ] **Step 5: Update `_drift_total` and Phase 3 to include taps**

In `script/brew-audit`, update the `_drift_total` line (line 204):

Replace:
```bash
_drift_total=$(( ${#drift_formulae[@]} + ${#drift_casks[@]} ))
```

With:
```bash
_drift_total=$(( ${#drift_taps[@]} + ${#drift_formulae[@]} + ${#drift_casks[@]} ))
```

In Phase 3 interactive review, add tap handling. In the "Add all" case (after line 318, `for f in "${drift_formulae[@]}"...`), insert before the formula loop:

```bash
    for t in "${drift_taps[@]}"; do _add_to_brewfile "tap" "$t"; done
```

In the "Dismiss all" case (after line 312), insert before the formula loop:

```bash
    for t in "${drift_taps[@]}"; do _add_to_ignore "$t"; done
```

In the "Review one by one" case (case 2, before the drift formulae loop at line 328), insert:

```bash
    # Drift taps
    for t in "${drift_taps[@]}"; do
      printf "  %s (tap)\n" "$t"
      _item_response="$(prompt_choice "Action" "Add to Brewfile" "Ignore (permanent)" "Skip (for now)")"
      printf "\n"
      case "$_item_response" in
        1) _add_to_brewfile "tap" "$t" ;;
        2) _add_to_ignore "$t" ;;
        3) ;;
      esac
    done

```

- [ ] **Step 6: Verify syntax on both files**

Run:
```bash
bash -n script/bootstrap && bash -n script/brew-audit
```

Expected: no output (clean parse).

- [ ] **Step 7: Commit**

```bash
git add Brewfile script/bootstrap script/brew-audit
git commit -m "Add tap drift detection to bootstrap and brew-audit

Declare taps in Brewfile, compare against brew tap output in both
bootstrap drift check and brew-audit Phase 1. Untracked taps surface
in warnings and interactive review."
```

---

### Task 6: Reporting — inline drift names in bootstrap

**Files:**
- Modify: `script/bootstrap` (drift result reporting section — the block from Task 4 Step 3)

- [ ] **Step 1: Replace the drift result reporting with inline names**

Replace the drift reporting block (from Task 4, Step 3):

```bash
  if $_drift_skipped; then
    _ACTIONABLE_WARNINGS+=("drift check skipped: brew query failed (Homebrew may be broken)")
  elif [[ $_audit_count -gt 0 ]]; then
    _ACTIONABLE_WARNINGS+=("$_audit_count packages not in Brewfile — run script/brew-audit")
  fi
```

With:

```bash
  if $_drift_skipped; then
    _ACTIONABLE_WARNINGS+=("drift check skipped: brew query failed (Homebrew may be broken)")
  elif [[ $_audit_count -gt 0 ]]; then
    _preview="${_drift_names[*]:0:5}"
    _msg="$_audit_count packages not in Brewfile: ${_preview// /, }"
    if [[ $_audit_count -gt 5 ]]; then
      _msg+=" ..."
    fi
    _msg+=" — run script/brew-audit"
    _ACTIONABLE_WARNINGS+=("$_msg")
  fi
```

- [ ] **Step 2: Update the substep spinner message too**

Replace the substep reporting in the non-verbose path. Currently:

```bash
    if [[ $_audit_count -gt 0 ]]; then
      substep_stop warn "drift check ($_audit_count untracked)"
    else
      substep_stop ok "drift check"
    fi
```

With:

```bash
    if $_drift_skipped; then
      substep_stop warn "drift check (skipped — brew query failed)"
    elif [[ $_audit_count -gt 0 ]]; then
      _sub_preview="${_drift_names[*]:0:3}"
      substep_stop warn "drift check ($_audit_count untracked: ${_sub_preview// /, })"
    else
      substep_stop ok "drift check"
    fi
```

The substep message shows 3 names (shorter, for the spinner line) while the actionable warning shows 5.

- [ ] **Step 3: Update the verbose path too**

Replace:

```bash
    [[ $_audit_count -gt 0 ]] && log_warn "$_audit_count packages not in Brewfile — run script/brew-audit"
```

With:

```bash
    if $_drift_skipped; then
      log_warn "drift check skipped: brew query failed (Homebrew may be broken)"
    elif [[ $_audit_count -gt 0 ]]; then
      _preview="${_drift_names[*]:0:5}"
      _msg="$_audit_count packages not in Brewfile: ${_preview// /, }"
      [[ $_audit_count -gt 5 ]] && _msg+=" ..."
      log_warn "$_msg — run script/brew-audit"
    fi
```

- [ ] **Step 4: Verify syntax**

Run:
```bash
bash -n script/bootstrap
```

Expected: no output (clean parse).

- [ ] **Step 5: Commit**

```bash
git add script/bootstrap
git commit -m "Show drift package names inline in bootstrap output

Display first 5 names in the actionable warning and first 3 in the
substep spinner. Makes it immediately clear what drifted without
needing to run brew-audit."
```

---

### Task 7: Diagnostics — create `script/brew-health`

**Files:**
- Create: `script/brew-health`

- [ ] **Step 1: Create `script/brew-health`**

```bash
#!/usr/bin/env bash
#
# brew-health
#
# Diagnoses common Homebrew problems: lock contention, fsmonitor in tap
# repos, obsolete taps, disabled formulae, orphaned casks, and Brewfile
# satisfaction. Run manually or auto-invoked on Phase 4 bootstrap failure.

set -euo pipefail

cd "$(dirname "$0")/.."
DOTFILES_ROOT=$(pwd -P)
BREWFILE="$DOTFILES_ROOT/Brewfile"

# shellcheck source=lib/output.sh
source "$DOTFILES_ROOT/script/lib/output.sh"

# Source localrc to pick up HOMEBREW_BUNDLE_CASK_SKIP
# shellcheck disable=SC1091
[[ -f "$HOME/.localrc" ]] && source "$HOME/.localrc"

_failures=0

_check_pass() { printf "  ${_GREEN}✓${_RST} %s\n" "$1"; }
_check_fail() { printf "  ${_RED}✗${_RST} %s\n" "$1"; _failures=$((_failures + 1)); }
_check_detail() { printf "      %s\n" "$1"; }

# ---------------------------------------------------------------------------
# Check 1: Homebrew reachable
# ---------------------------------------------------------------------------

_check_brew_reachable() {
  local prefix
  if prefix="$(brew --prefix 2>&1)"; then
    _check_pass "Homebrew reachable ($prefix)"
    return 0
  else
    _check_fail "Homebrew not reachable"
    _check_detail "Install: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Check 2: Update lock not held
# ---------------------------------------------------------------------------

_check_update_lock() {
  local lock_file
  lock_file="$(brew --prefix)/var/homebrew/locks/update"

  if [[ ! -f "$lock_file" ]]; then
    _check_pass "Update lock not held"
    return 0
  fi

  local holders
  holders="$(lsof "$lock_file" 2>/dev/null || true)"

  if [[ -z "$holders" ]] || [[ "$(echo "$holders" | wc -l)" -le 1 ]]; then
    _check_pass "Update lock not held"
    return 0
  fi

  _check_fail "Update lock is held"

  # Show each holder process
  echo "$holders" | tail -n +2 | while IFS= read -r line; do
    local pid cmd
    pid="$(echo "$line" | awk '{print $2}')"
    cmd="$(echo "$line" | awk '{print $1}')"
    _check_detail "$cmd (PID $pid)"

    # Try to find the associated repo for git processes
    if [[ "$cmd" == "git" ]]; then
      local cwd
      cwd="$(lsof -p "$pid" 2>/dev/null | grep cwd | awk '{print $NF}')" || true
      if [[ -n "$cwd" ]]; then
        _check_detail "  working dir: $cwd"
      fi
    fi
  done

  _check_detail "fix: kill the process(es) above, then retry"
  return 1
}

# ---------------------------------------------------------------------------
# Check 3: fsmonitor disabled in tap repos
# ---------------------------------------------------------------------------

_check_fsmonitor_taps() {
  local taps_dir
  taps_dir="$(brew --repository)/Library/Taps"

  if [[ ! -d "$taps_dir" ]]; then
    _check_pass "fsmonitor in tap repos (no taps directory)"
    return 0
  fi

  local bad_taps=()
  while IFS= read -r tap_dir; do
    [[ -d "$tap_dir/.git" ]] || continue
    local val
    val="$(git -C "$tap_dir" config --get core.fsmonitor 2>/dev/null || echo "unset")"
    if [[ "$val" == "true" ]]; then
      bad_taps+=("$(basename "$(dirname "$tap_dir")")/$(basename "$tap_dir")")
    fi
  done < <(find "$taps_dir" -mindepth 2 -maxdepth 2 -type d)

  if [[ ${#bad_taps[@]} -eq 0 ]]; then
    _check_pass "fsmonitor disabled in tap repos"
    return 0
  fi

  _check_fail "fsmonitor enabled in tap repos"
  for t in "${bad_taps[@]}"; do
    _check_detail "$t has core.fsmonitor=true"
  done
  _check_detail "fix: add includeIf overrides in ~/.gitconfig (see git/gitconfig.symlink)"
  return 1
}

# ---------------------------------------------------------------------------
# Check 4: No obsolete taps
# ---------------------------------------------------------------------------

_check_obsolete_taps() {
  local expected_taps=()
  if [[ -f "$BREWFILE" ]]; then
    while IFS= read -r _tap_line; do
      expected_taps+=("$_tap_line")
    done < <(grep "^tap " "$BREWFILE" | sed "s/tap '\\(.*\\)'/\\1/")
  fi

  local untracked=()
  while IFS= read -r tap; do
    [[ -z "$tap" ]] && continue
    [[ "$tap" == "homebrew/core" || "$tap" == "homebrew/cask" ]] && continue
    local found=false
    for t in "${expected_taps[@]:-}"; do
      [[ "$t" == "$tap" ]] && { found=true; break; }
    done
    if ! $found; then
      untracked+=("$tap")
    fi
  done < <(brew tap 2>/dev/null)

  if [[ ${#untracked[@]} -eq 0 ]]; then
    _check_pass "No obsolete taps"
    return 0
  fi

  _check_fail "Untracked taps found"
  for t in "${untracked[@]}"; do
    # Check if deprecated
    local info
    info="$(brew tap-info "$t" 2>&1 || true)"
    if echo "$info" | grep -qi "deprecated\|does not exist\|invalid"; then
      _check_detail "$t — deprecated/invalid, run: brew untap $t"
    else
      _check_detail "$t — not in Brewfile, add or: brew untap $t"
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# Check 5: No disabled formulae
# ---------------------------------------------------------------------------

_check_disabled_formulae() {
  local json
  json="$(brew info --json=v2 --installed 2>/dev/null || true)"

  if [[ -z "$json" ]]; then
    _check_pass "No disabled formulae (could not query)"
    return 0
  fi

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

  if [[ -z "$disabled" ]]; then
    _check_pass "No disabled formulae"
    return 0
  fi

  _check_fail "Disabled formulae installed"
  while IFS= read -r line; do
    local name="${line%% (*}"
    _check_detail "$line"
    _check_detail "  run: brew uninstall $name"
  done <<< "$disabled"
  return 1
}

# ---------------------------------------------------------------------------
# Check 6: Cask app artifacts present
# ---------------------------------------------------------------------------

_check_orphaned_casks() {
  local orphaned=()

  while IFS= read -r cask; do
    [[ -z "$cask" ]] && continue
    # Get the expected app artifact path
    local app_name
    app_name="$(brew info --cask --json=v2 "$cask" 2>/dev/null | python3 -c "
import json, sys
data = json.load(sys.stdin)
for c in data.get('casks', []):
    for a in c.get('artifacts', []):
        if isinstance(a, dict) and 'app' in a:
            for app in a['app']:
                print(app)
                sys.exit(0)
" 2>/dev/null || true)"

    if [[ -n "$app_name" ]] && [[ ! -e "/Applications/$app_name" ]]; then
      orphaned+=("$cask|$app_name")
    fi
  done < <(brew list --cask 2>/dev/null)

  if [[ ${#orphaned[@]} -eq 0 ]]; then
    _check_pass "Cask app artifacts present"
    return 0
  fi

  _check_fail "Orphaned cask metadata"
  for entry in "${orphaned[@]}"; do
    local cask="${entry%%|*}" app="${entry#*|}"
    _check_detail "$cask — /Applications/$app missing"
    _check_detail "  run: brew uninstall --cask $cask"
  done
  return 1
}

# ---------------------------------------------------------------------------
# Check 7: Brewfile satisfaction
# ---------------------------------------------------------------------------

_check_bundle_satisfaction() {
  local output
  if output="$(brew bundle check --file="$BREWFILE" 2>&1)"; then
    _check_pass "Brewfile satisfied"
    return 0
  else
    _check_fail "Brewfile not satisfied"
    while IFS= read -r line; do
      _check_detail "$line"
    done <<< "$output"
    _check_detail "run: brew bundle --file=$BREWFILE"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Run all checks
# ---------------------------------------------------------------------------

printf "\n  ${_BOLD}brew-health${_RST}\n\n"

# Check 1 is a gate — if Homebrew isn't reachable, skip everything else
if ! _check_brew_reachable; then
  printf "\n  ${_RED}${_BOLD}1 issue found${_RST} (Homebrew not reachable — remaining checks skipped)\n\n"
  exit 1
fi

_check_update_lock
_check_fsmonitor_taps
_check_obsolete_taps
_check_disabled_formulae
_check_orphaned_casks
_check_bundle_satisfaction

if [[ $_failures -eq 0 ]]; then
  printf "\n  ${_GREEN}${_BOLD}All checks passed${_RST}\n\n"
  exit 0
else
  printf "\n  ${_RED}${_BOLD}%d issue(s) found${_RST}\n\n" "$_failures"
  exit 1
fi
```

- [ ] **Step 2: Make the script executable**

Run:
```bash
chmod +x script/brew-health
```

- [ ] **Step 3: Verify syntax**

Run:
```bash
bash -n script/brew-health
```

Expected: no output (clean parse).

- [ ] **Step 4: Commit**

```bash
git add script/brew-health
git commit -m "Add brew-health diagnostic script

Standalone tool that checks: Homebrew reachable, update lock, fsmonitor
in taps, obsolete taps, disabled formulae, orphaned cask metadata, and
Brewfile satisfaction. Reports pass/fail per check with fix commands."
```

---

### Task 8: Wire `brew-health` into bootstrap on Phase 4 failure

**Files:**
- Modify: `script/bootstrap:94-97` (`_on_error` trap)

- [ ] **Step 1: Update `_on_error` to run `brew-health` on Phase 4 failure**

Replace lines 94-97 in `script/bootstrap`:

```bash
_on_error() {
  _spinner_cleanup
  log_error_context "$LOGFILE" "$_current_phase"
}
```

With:

```bash
_on_error() {
  _spinner_cleanup
  log_error_context "$LOGFILE" "$_current_phase"
  if [[ "$_current_phase" == "Installing Software" ]] \
     && [[ -x "$DOTFILES_ROOT/script/brew-health" ]]; then
    printf "\n"
    "$DOTFILES_ROOT/script/brew-health" || true
  fi
}
```

The `|| true` prevents brew-health's own nonzero exit from interfering with the error trap. The `-x` check ensures the script exists and is executable.

- [ ] **Step 2: Verify syntax**

Run:
```bash
bash -n script/bootstrap
```

Expected: no output (clean parse).

- [ ] **Step 3: Commit**

```bash
git add script/bootstrap
git commit -m "Auto-run brew-health on Phase 4 bootstrap failure

When Installing Software fails, automatically run the brew-health
diagnostic to surface lock contention, obsolete taps, disabled
formulae, and other Homebrew issues alongside the error log."
```

---

### Task 9: Final verification

- [ ] **Step 1: Run syntax checks on all modified files**

```bash
bash -n script/bootstrap && bash -n script/lib/output.sh && bash -n script/brew-audit && bash -n script/brew-health
```

Expected: no output (all clean).

- [ ] **Step 2: Run shellcheck on new script**

```bash
shellcheck script/brew-health
```

Expected: clean or only style warnings (SC2086-type). Fix any errors.

- [ ] **Step 3: Verify gitconfig syntax**

```bash
git config --file git/gitconfig.symlink --list > /dev/null
```

Expected: exits 0 (valid config).

- [ ] **Step 4: Verify Brewfile ordering**

```bash
# Taps should be alphabetical, brews alphabetical, casks alphabetical
head -20 Brewfile
```

Expected: taps section at top (after the skip-list loader), alphabetically ordered, then brew section, then cask section.

- [ ] **Step 5: Run `script/brew-health` to see it work**

```bash
script/brew-health
```

Expected: all checks pass on the current machine (since the fsmonitor fix is in place and no stale state remains). Output should show 7 green checkmarks.
