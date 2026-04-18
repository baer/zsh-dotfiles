# Homebrew Hardening Design

Harden the dotfiles project's Homebrew handling so bootstrap is robust on any machine — new or years-old — by preventing known bad states, diagnosing unavoidable ones clearly, and surfacing actionable fixes instead of generic errors.

## Root Cause

`core.fsmonitor=true` in the global gitconfig causes Git to auto-start fsmonitor daemons inside Homebrew tap repos during `brew update`. Those daemons inherit Homebrew's update lock FD and keep it held after the original brew process exits. Future `brew update` calls fail with `lockf: 200: already locked`.

Secondary failures discovered on the same machine: an obsolete `homebrew/cask-fonts` tap, a disabled `dbt-postgres` formula, and orphaned `pgadmin4` cask metadata with a missing app bundle.

## Approach

Six layers, ordered by the diagnostic path: prevention, detection, failure handling, drift detection, reporting, diagnostics. Each layer catches what the previous one missed.

---

## Layer 1: Prevention — fsmonitor fix + documentation

### Changes

**`git/gitconfig.symlink`** — Add `includeIf` blocks that load a Homebrew-specific gitconfig for tap repos on both Apple Silicon and Intel paths:

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

**`git/gitconfig-homebrew.symlink`** — New file:

```gitconfig
[core]
        fsmonitor = false
```

Symlinked to `~/.gitconfig-homebrew` by bootstrap (follows the existing `*.symlink` convention).

**`AGENTS.md`** — New gotcha entry under "Gotchas":

> **fsmonitor + Homebrew**: `core.fsmonitor=true` is enabled globally for performance, but disabled in Homebrew tap repos via `includeIf` + `git/gitconfig-homebrew.symlink`. Without this override, fsmonitor daemons inherit Homebrew's update lock FD and permanently block `brew update`. If you see `lockf: already locked` errors, check: `lsof "$(brew --prefix)/var/homebrew/locks/update"`.

---

## Layer 2: Detection — error hint patterns

### Changes

**`script/lib/output.sh` — `_detect_error_hint()`** — Add four new pattern matches after the existing ones, ordered most-specific first:

1. **Lock contention**: `lockf:` + `already locked` OR `Another.*brew update.*already running`
   - Hint: `"Homebrew update lock is held by another process.\n        Run: lsof \"$(brew --prefix)/var/homebrew/locks/update\" to find the holder."`

2. **Obsolete tap**: `does not exist! Run.*brew untap`
   - Hint: `"An obsolete tap is blocking brew update.\n        The error message above includes the untap command to fix it."`

3. **Disabled formula**: `has been disabled because`
   - Hint: `"A disabled formula is causing errors during upgrade.\n        Uninstall it: brew uninstall <formula>"`

4. **Missing cask app**: `It seems the App source` + `is not there`
   - Hint: `"A cask has metadata but its app is missing.\n        Reinstall: brew reinstall --cask <cask> or uninstall: brew uninstall --cask <cask>"`

Each returns immediately, matching the existing early-return style.

---

## Layer 3: Failure handling — smarter brew upgrade + honest drift queries

### Changes

**`script/bootstrap` — `brew upgrade` block (lines 404-410):**

Replace the blanket warning with output inspection. After `brew upgrade` fails, read the last 30 lines of the log. If they contain real failure patterns (`has been disabled`, `is not there`, `Permission denied`, `locked`), use `substep_stop fail` instead of `substep_stop warn`. The fail case doesn't abort bootstrap — it surfaces the issue visually as red instead of yellow so the user knows it needs attention.

```bash
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

Apply the same classification to the verbose path (lines 387-399), which currently has no error handling for `brew upgrade`.

**`script/bootstrap` — drift check (lines 484-492):**

Replace `brew leaves 2>/dev/null` and `brew list --cask 2>/dev/null` with explicit exit code checking. If either command fails, add a "drift check skipped" warning instead of silently reporting zero drift.

```bash
if _brew_leaves="$(brew leaves 2>&1)"; then
  while IFS= read -r leaf; do
    # ... existing drift logic
  done <<< "$_brew_leaves"
else
  _ACTIONABLE_WARNINGS+=("drift check skipped: 'brew leaves' failed")
fi
```

Same pattern for `brew list --cask`.

---

## Layer 4: Tap drift — bootstrap + brew-audit

### Changes

**`script/bootstrap` drift check (~line 475):**

After the existing formula/cask drift loops, add a tap drift loop. Extract expected taps from the Brewfile (`grep "^tap "`), compare against `brew tap` output. Skip implicit taps (`homebrew/core`, `homebrew/cask`). Count untracked taps toward `_audit_count` and collect names into `_drift_names` (for Layer 5).

**Prerequisite**: Add missing taps to Brewfile. Currently `homebrew/bundle` and `stripe/stripe-cli` are installed but not declared. They should be added as `tap` entries at the top of the Brewfile (before the `brew` section) to make the Brewfile a complete declaration.

**`script/brew-audit` Phase 1 (~line 188):**

Add a tap drift section before the existing formula drift. Same comparison logic. Display format:

```
  Taps not in Brewfile (1):
    i stripe/stripe-cli
```

Taps get folded into the existing Phase 3 interactive review with the same add/ignore/skip options. The `_add_to_brewfile` helper gets a `tap` type alongside the existing `brew`/`cask` types.

---

## Layer 5: Reporting — inline drift names

### Changes

**`script/bootstrap` drift check (~line 494):**

Collect drift names into an array as the formula/cask/tap loops iterate. Show the first 5 names inline in the warning:

```bash
if [[ $_audit_count -gt 0 ]]; then
  _preview="${_drift_names[*]:0:5}"
  _msg="$_audit_count packages not in Brewfile: ${_preview// /, }"
  if [[ $_audit_count -gt 5 ]]; then
    _msg+=" ..."
  fi
  _msg+=" — run script/brew-audit"
  _ACTIONABLE_WARNINGS+=("$_msg")
fi
```

Produces: `18 packages not in Brewfile: foo, bar, baz, qux, quux ... — run script/brew-audit`

Tap names are prefixed with `tap:` (e.g., `tap:stripe/stripe-cli`) to distinguish them from formulae/casks.

The substep spinner message gets the same preview treatment.

---

## Layer 6: Diagnostics — `script/brew-health`

### New file: `script/brew-health`

A standalone diagnostic script for Homebrew issues. Runnable manually or automatically on Phase 4 failure.

### Checks

| # | Check | How | Pass | Fail |
|---|-------|-----|------|------|
| 1 | Homebrew reachable | `brew --prefix` | Shows prefix path | Suggests install command |
| 2 | Update lock not held | `lsof` on `$(brew --prefix)/var/homebrew/locks/update` | No holders | Shows PID, command, associated repo; suggests `kill <pid>` |
| 3 | fsmonitor disabled in taps | `git -C <tap> config core.fsmonitor` per tap | All false/unset | Lists offending taps; suggests the `includeIf` fix |
| 4 | No obsolete taps | Compare `brew tap` against Brewfile + implicit allowlist | All accounted for | Lists untracked taps; flags deprecated ones via `brew tap-info`; suggests `brew untap` |
| 5 | No disabled formulae | `brew info --json=v2 --installed`, check `disabled` field | None disabled | Lists disabled formulae with date/message; suggests `brew uninstall` |
| 6 | Cask app artifacts present | For each cask, check that its app artifact path exists | All present | Lists orphaned casks; suggests `brew reinstall --cask` or `brew uninstall --cask` |
| 7 | Brewfile satisfied | `brew bundle check --file=<Brewfile>` | Satisfied | Shows what's missing |

### Structure

Each check is a function returning 0 (pass) or 1 (fail). The runner iterates all checks, prints a result line per check, and exits with the number of failures.

Sources `script/lib/output.sh` for consistent formatting. Uses the existing `log_success`, `log_warn`, `log_error` helpers.

### Output format

```
  brew-health

  ✓ Homebrew reachable (/opt/homebrew)
  ✓ Update lock not held
  ✓ fsmonitor disabled in tap repos
  ✗ Obsolete taps found
      homebrew/cask-fonts — deprecated, run: brew untap homebrew/cask-fonts
  ✓ No disabled formulae
  ✗ Orphaned cask metadata
      pgadmin4 — /Applications/pgAdmin 4.app missing
      run: brew uninstall --cask pgadmin4
  ✓ Brewfile satisfied

  2 issues found
```

### What it does NOT do

- Does not fix anything automatically — diagnose and suggest only
- Does not run `brew doctor` (too slow, too noisy)
- Does not check network connectivity (covered by existing error hints)
- Does not run during successful bootstraps (zero added latency on happy path)

### Integration with bootstrap

Modify `_on_error` in `script/bootstrap` (~line 94): if `_current_phase` is "Installing Software" and `script/brew-health` exists, run it automatically after `log_error_context`:

```bash
_on_error() {
  _spinner_cleanup
  log_error_context "$LOGFILE" "$_current_phase"
  if [[ "$_current_phase" == "Installing Software" ]] \
     && [[ -x "$DOTFILES_ROOT/script/brew-health" ]]; then
    printf "\n"
    "$DOTFILES_ROOT/script/brew-health"
  fi
}
```

---

## Files Changed

| File | Change type |
|------|-------------|
| `git/gitconfig.symlink` | Edit — add `includeIf` blocks |
| `git/gitconfig-homebrew.symlink` | New — fsmonitor override for taps |
| `AGENTS.md` | Edit — add fsmonitor gotcha |
| `script/lib/output.sh` | Edit — add 4 error hint patterns |
| `script/bootstrap` | Edit — smarter upgrade handling, honest drift queries, tap drift, inline names, brew-health on error |
| `script/brew-audit` | Edit — add tap drift to Phase 1 and Phase 3 |
| `Brewfile` | Edit — add missing `tap` declarations |
| `script/brew-health` | New — standalone diagnostic script |

## Out of Scope

- Command-scoped log sentinels (unnecessary for sequential execution)
- Full `brew doctor` integration (too slow)
- Automatic remediation (too risky for a bootstrap script)
- `brew-audit` Phase 2 changes (adoptable apps logic is unrelated)
