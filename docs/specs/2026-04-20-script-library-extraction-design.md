# Script Library Extraction & Test Harness

**Date:** 2026-04-20
**Status:** Draft
**Scope:** `script/` directory refactoring — extract shared domain logic into libraries, add tests

## Problem

The `script/` directory contains 2,750 lines of bash across 5 files:

| File | Lines | Role |
|------|-------|------|
| `lib/output.sh` | 883 | Shared UI library (colors, spinners, prompts, box drawing) |
| `bootstrap` | 645 | First-time dotfiles setup orchestrator |
| `brew-audit` | 551 | Interactive Brewfile drift review |
| `brew-health` | 387 | Homebrew diagnostic checks |
| `brew-skip-detect` | 284 | Pre-installed cask detection |

Four categories of domain logic are duplicated across scripts:

1. **Brewfile parsing** — Section extraction, membership checks, and sorted insertion are implemented independently in bootstrap, brew-audit, and brew-health (6+ occurrences).
2. **Drift collection** — Loops comparing installed packages to Brewfile contents appear in bootstrap (lines 475–541), brew-audit (lines 279–338), and brew-health (lines 132–148). Each has slightly different filtering logic, making divergence a latent bug source.
3. **Skip-list and ignore-file filtering** — The pattern `echo " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " | grep -q " $item "` appears 4+ times across 3 files. Ignore-file checks (`grep -qx "$pkg" "$_ignore_file"`) appear 5 times in bootstrap alone.
4. **Cask artifact detection** — brew-health (lines 212–248) and brew-skip-detect (lines 73–141) both query `brew info --cask --json=v2` and parse the result with inline Python to detect app presence.

Additionally:
- `_add_to_brewfile()` (lines 97–139) and `_add_mas_to_brewfile()` (lines 143–182) in brew-audit are 86 lines of nearly identical temp-file-and-sort logic.
- brew-audit uses manual `spinner_start`/`spinner_stop` calls in 8 places instead of the existing `run_with_substep_spinner()` abstraction from output.sh.
- All JSON parsing (5 call sites) uses inline `python3 -c` scripts with no dependency check. `jq` is a better fit.
- Bootstrap's Phase 4 is 267 lines (lines 340–606) mixing 6 concerns.

There are no tests.

## Goals

1. Eliminate duplicated domain logic by extracting it into shared libraries.
2. Make each script shorter and focused on orchestration, not implementation details.
3. Add a bats-core test harness for all extracted library functions.
4. Replace inline Python JSON parsing with `jq`.
5. Preserve identical user-facing behavior (output, prompts, exit codes, CLI flags).

## Non-Goals

- Rewriting scripts in another language.
- Changing `lib/output.sh` (already well-structured).
- Changing the public interface of any script.
- Adding new features or changing user-facing behavior.
- End-to-end testing of orchestrator scripts.

## Design

### New Libraries

Four new files in `script/lib/`, following the same sourcing pattern as `output.sh`:

```
script/lib/
├── output.sh          # existing, unchanged
├── brewfile.sh        # Brewfile parsing and mutation
├── drift.sh           # drift collection (depends on brewfile.sh, skip-lists.sh)
├── skip-lists.sh      # skip/ignore list helpers
└── cask-detect.sh     # cask artifact detection via jq
```

Each library:
- Uses `#!/usr/bin/env bash` shebang for shellcheck compatibility (not executed directly).
- Sources its dependencies (e.g., drift.sh sources brewfile.sh and skip-lists.sh).
- Prefixes all functions with `_` to signal they are internal/library functions.
- Guards against double-sourcing with `[[ -n "${_LIB_NAME_LOADED:-}" ]] && return 0`.
- Expects `BREWFILE` or `DOTFILES_ROOT` to be set by the caller.

#### `lib/brewfile.sh`

Replaces: Brewfile grep/sed parsing (3 files, 6+ sites), `_add_to_brewfile` + `_add_mas_to_brewfile` (brew-audit lines 97–182).

```bash
# Reading
_brewfile_list_section()    # (type) → prints names in section, one per line
                            # type: "tap"|"brew"|"cask"|"mas"
                            # Replaces: grep "^tap " | sed "s/tap '\(.*\)'/\1/"
                            # For mas: extracts name from "mas 'Name', id: 123"

_brewfile_contains()        # (type, name) → exit 0 if present, 1 if not
                            # type: "tap"|"brew"|"cask"|"mas"
                            # For tap/brew/cask: exact line match "type 'name'"
                            # For mas: match by id using grep -q "id: ${name}$"
                            # Replaces: grep -qx "brew '$leaf'" "$BREWFILE" (×6)

# Writing
_brewfile_insert()          # (type, name [, id]) → insert line in sorted position
                            # type: "tap"|"brew"|"cask"|"mas"
                            # For mas: requires name AND id args, formats as:
                            #   mas 'Name', id: 123
                            # For others: formats as: type 'name'
                            # Handles: section doesn't exist (append with blank line separator),
                            #          alphabetical insertion, temp file cleanup
                            # Replaces: _add_to_brewfile() + _add_mas_to_brewfile() (86 lines)
```

**Behavioral notes:**
- `_brewfile_contains` for mas entries matches by numeric ID (the stable identifier), not by app name (which can change). This matches current bootstrap behavior (line 510: `grep -q "id: ${_mas_id}$"`).
- `_brewfile_insert` writes the line, logs success via `log_success`, and returns. The caller is responsible for running `brew bundle` afterward.
- `BREWFILE` variable must be set before sourcing. All functions read/write `$BREWFILE`.

#### `lib/skip-lists.sh`

Replaces: 4+ inline `grep -q` patterns for skip lists, 5+ ignore-file checks.

```bash
_is_cask_skipped()     # (cask) → exit 0 if in HOMEBREW_BUNDLE_CASK_SKIP
                       # Replaces: echo " ${HOMEBREW_BUNDLE_CASK_SKIP:-} " | grep -q " $cask "
                       # bootstrap:491, brew-audit:36, brew-skip-detect:55

_is_mas_skipped()      # (id) → exit 0 if in HOMEBREW_BUNDLE_MAS_SKIP
                       # Replaces: echo " ${HOMEBREW_BUNDLE_MAS_SKIP:-} " | grep -q " $id "
                       # bootstrap:508, brew-audit:41

_is_audit_ignored()    # (name) → exit 0 if in ~/.brew-audit-ignore
                       # Replaces: [[ -f "$file" ]] && grep -qx "$pkg" "$file"
                       # bootstrap:478,492,509,529 and brew-audit:31
                       # Uses AUDIT_IGNORE_FILE="${AUDIT_IGNORE_FILE:-$HOME/.brew-audit-ignore}"
```

**Behavioral notes:**
- All three functions are pure predicates — no side effects, no output.
- `_is_audit_ignored` returns 1 (not ignored) if the ignore file doesn't exist.
- The ignore file path is configurable via `AUDIT_IGNORE_FILE` for testability. Defaults to `$HOME/.brew-audit-ignore`.

#### `lib/drift.sh`

Replaces: Drift collection loops in bootstrap (lines 475–541), brew-audit (lines 279–338), and brew-health (lines 132–148).

Sources `lib/brewfile.sh` and `lib/skip-lists.sh`.

```bash
_collect_drift_taps()       # () → prints untracked tap names, one per line
                            # Compares: brew tap vs _brewfile_list_section tap
                            # Filters: _is_audit_ignored
                            # Replaces: bootstrap:520-541, brew-audit:281-298, brew-health:132-148

_collect_drift_formulae()   # () → prints untracked formula names, one per line
                            # Compares: brew leaves vs _brewfile_contains brew
                            # Filters: _is_audit_ignored
                            # Replaces: bootstrap:475-483, brew-audit:311-314

_collect_drift_casks()      # () → prints untracked cask names, one per line
                            # Compares: brew list --cask vs _brewfile_contains cask
                            # Filters: _is_cask_skipped, _is_audit_ignored
                            # Replaces: bootstrap:489-497, brew-audit:318-322

_collect_drift_mas()        # () → prints "id name" pairs, one per line
                            # Compares: mas list vs _brewfile_contains mas (by id)
                            # Filters: _is_mas_skipped, _is_audit_ignored
                            # Replaces: bootstrap:504-513, brew-audit:327-337

_count_total_drift()        # () → prints integer count of all untracked items
                            # Convenience wrapper used by bootstrap for its summary count
```

**Behavioral notes:**
- Each function writes to stdout. Callers capture into arrays via `mapfile` or process line-by-line.
- If a `brew` command fails (e.g., no network), the function prints nothing and returns 0. The caller sees zero drift, which is the safe default. This matches current bootstrap behavior (lines 475–476: `if _brew_leaves="$(brew leaves 2>&1)"; then`).
- brew-health uses drift differently — it doesn't filter by ignore/skip lists because it's diagnosing problems, not auditing. brew-health will call `_brewfile_list_section` directly and do its own comparison, rather than using `_collect_drift_*`. This keeps the drift functions clean (always filter) while letting brew-health opt out.

#### `lib/cask-detect.sh`

Replaces: Python-based cask artifact detection in brew-skip-detect (lines 73–141) and brew-health (lines 212–248).

```bash
_cask_app_artifacts()       # (json on stdin) → prints /Applications/*.app paths declared by cask
                            # Parses: artifacts[].app paths from brew info JSON via jq
                            # Replaces: brew-skip-detect Strategy 1 (lines 87-96)

_cask_uninstall_artifacts() # (json on stdin) → prints uninstall.delete paths declared by cask
                            # Parses: artifacts[].uninstall.delete paths from brew info JSON
                            # Replaces: brew-skip-detect Strategy 2 (lines 106-116)

_cask_pkgutil_ids()         # (json on stdin) → prints pkgutil receipt IDs declared by cask
                            # Parses: artifacts[].uninstall.pkgutil IDs from brew info JSON
                            # Replaces: brew-skip-detect Strategy 3 (lines 127-140)

_is_cask_preinstalled()     # (cask_token) → exit 0 if app found on disk via any strategy
                            # Fetches brew info JSON ONCE, pipes to each strategy function
                            # Runs all three strategies in order, returns on first hit
                            # Sets global _DETECTED_APP_PATH to the found path (for UI)
                            # Replaces: brew-skip-detect outer loop (lines 73-141)

_find_orphaned_cask_apps()  # () → prints "token|app_name" for installed casks whose
                            #       /Applications path no longer exists
                            # Queries: brew info --cask --json=v2 --installed | jq
                            # Replaces: brew-health _check_orphaned_casks (lines 212-248)
```

**Behavioral notes:**
- All functions use `jq` instead of `python3`. If `jq` is not available, functions print an error to stderr and return 1.
- `_cask_app_artifacts`, `_cask_uninstall_artifacts`, and `_cask_pkgutil_ids` read JSON from stdin (not from `brew info`). This lets the caller fetch JSON once and pipe it to each strategy, matching the current brew-skip-detect behavior (line 75: single `brew info` call, JSON reused for all three strategies). No performance regression.
- `_is_cask_preinstalled` is the only function that calls `brew info`. It fetches once, stores in a variable, and pipes to each strategy function via `echo "$json" | _cask_app_artifacts`.
- `_find_orphaned_cask_apps` makes a single bulk `brew info --installed` call, which is how brew-health currently works.

### Changes to Existing Scripts

#### `bootstrap` (~645 → ~400 lines)

**New sources** (after existing `source lib/output.sh`):
```bash
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
source "$DOTFILES_ROOT/script/lib/drift.sh"
```

**Phase 4 decomposition** — The current 267-line Phase 4 (lines 340–606) splits into focused functions:

| Function | Responsibility | Approx lines |
|----------|---------------|--------------|
| `_phase4_ensure_homebrew()` | Check for / install Homebrew | ~30 |
| `_phase4_update_and_bundle()` | `brew update`, `brew upgrade`, `brew bundle` with spinner | ~60 |
| `_phase4_detect_drift()` | Call `_count_total_drift()`, report summary | ~25 |
| `_phase4_check_vulnerabilities()` | Query brew-vulns if available | ~30 |

The phase orchestration stays inline:
```bash
phase_start 4 "Installing software"
_phase4_ensure_homebrew
_phase4_update_and_bundle
# ... brew-skip-detect sourcing (unchanged) ...
_phase4_detect_drift
_phase4_check_vulnerabilities
phase_end ok "..."
```

**Drift detection replacement** — Lines 472–541 (the 4 drift loops + ignore/skip filtering) replaced with:
```bash
_drift_count="$(_count_total_drift)"
```

This is possible because `_count_total_drift` encapsulates all four collection functions with filtering.

#### `brew-audit` (~551 → ~350 lines)

**New sources:**
```bash
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
source "$DOTFILES_ROOT/script/lib/drift.sh"
source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
```

**Deletions:**
- `_is_ignored()` (lines 29–32) → replaced by `_is_audit_ignored()` from skip-lists.sh
- `_is_in_cask_skip()` (lines 34–37) → replaced by `_is_cask_skipped()` from skip-lists.sh
- `_is_in_mas_skip()` (lines 39–42) → replaced by `_is_mas_skipped()` from skip-lists.sh
- `_add_to_brewfile()` (lines 97–139) → replaced by `_brewfile_insert()` from brewfile.sh
- `_add_mas_to_brewfile()` (lines 143–182) → replaced by `_brewfile_insert()` with mas type
- Phase 1 drift collection loops (lines 279–338) → replaced by `_collect_drift_*()` calls

**Spinner cleanup** — Replace 8 manual `spinner_start`/`spinner_stop` blocks with `run_with_substep_spinner`:

Current (lines 46–51):
```bash
spinner_start "brew untap $tap"
if brew untap "$tap" >> "$LOGFILE" 2>&1; then
  spinner_stop ok "brew untap $tap"
else
  spinner_stop fail "brew untap $tap (see .brew-audit.log)"
fi
```

Becomes:
```bash
run_with_substep_spinner "brew untap $tap" "$LOGFILE" brew untap "$tap"
```

Affected functions: `_remove_tap` (lines 46–51), `_remove_formula` (lines 69–74), `_remove_cask` (lines 79–84), `_adopt_cask` (lines 234–249).

**Note on `_adopt_cask`:** The trash-then-install sequence in `_adopt_cask` (lines 231–261) has two sequential spinner blocks with early-return logic between them. This cannot use `run_with_substep_spinner` directly because the second step depends on the first succeeding. These two blocks remain as manual spinner calls.

#### `brew-health` (~387 → ~300 lines)

**New sources:**
```bash
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
```

**Changes:**
- `_check_obsolete_taps()` (lines 128–167): Replace inline Brewfile parsing with `_brewfile_list_section tap`.
- `_check_orphaned_casks()` (lines 212–248): Replace inline Python with `_find_orphaned_cask_apps()`.
- `_check_disabled_formulae()` (lines 175–206): Replace Python `json.load` with `jq` query inline (this pattern is unique to brew-health, not worth extracting).

**Note:** brew-health does not use `lib/drift.sh` or `lib/skip-lists.sh`. Its diagnostic checks compare installed state against Brewfile without skip/ignore filtering, because it's diagnosing problems — not auditing drift.

#### `brew-skip-detect` (~284 → ~200 lines)

**New sources:**
```bash
source "$DOTFILES_ROOT/script/lib/brewfile.sh"
source "$DOTFILES_ROOT/script/lib/skip-lists.sh"
source "$DOTFILES_ROOT/script/lib/cask-detect.sh"
```

**Changes:**
- Cask collection from Brewfile (lines 43–48): Replace with `_brewfile_list_section cask`.
- Skip-list check (line 55): Replace with `_is_cask_skipped`.
- Three detection strategies (lines 73–141): Replace with `_is_cask_preinstalled` per cask.
- The interactive review loop (lines 177–247) and `~/.localrc` write logic stay in this script — they are specific to skip-detect's workflow.

### Python → jq Migration

Five `python3 -c` call sites replaced with `jq`:

| File | Lines | Current (Python) | Replacement (jq) |
|------|-------|-------------------|-------------------|
| brew-health | 183–192 | Parse disabled formulae from `brew info --json=v2` | `jq -r '.formulae[] \| select(.disabled) \| .name'` |
| brew-health | 222–234 | Parse orphaned cask app paths | Moved into `_find_orphaned_cask_apps()` in cask-detect.sh |
| brew-skip-detect | 87–96 | Extract `artifacts.app` paths | Moved into `_cask_app_artifacts()` in cask-detect.sh |
| brew-skip-detect | 106–116 | Extract `artifacts.uninstall.delete` paths | Moved into `_cask_uninstall_artifacts()` in cask-detect.sh |
| brew-skip-detect | 127–140 | Extract pkgutil receipt IDs | Moved into `_cask_pkgutil_ids()` in cask-detect.sh |

`jq` will be added to the Brewfile (`brew 'jq'`). The disabled-formulae check in brew-health stays inline (unique to that file, not worth extracting).

### Test Harness

**Framework:** bats-core, installed via Homebrew (`brew 'bats-core'`).

**Structure:**
```
test/
├── test_helper.bash          # source libraries, create temp BREWFILE, define mocks
├── fixtures/
│   ├── Brewfile.basic         # tap + brew + cask (3 entries each)
│   ├── Brewfile.full          # all 4 sections populated, 5+ entries each
│   └── Brewfile.empty         # empty file
└── lib/
    ├── brewfile.bats          # ~15 tests
    ├── skip-lists.bats        # ~8 tests
    ├── drift.bats             # ~10 tests
    └── cask-detect.bats       # ~8 tests
```

**test_helper.bash** provides:
- `BATS_TEST_TMPDIR`-based temp Brewfile (copied from fixtures, writable)
- Mock `brew` function that returns canned output (configurable per test)
- Mock `mas` function
- Mock `jq` passthrough (real jq, but controlled input)
- Sources all four libraries

**What gets tested:**

| Library | Key test cases |
|---------|---------------|
| brewfile.sh | List each section type; contains hit/miss for each type; insert into existing section (verify sort order); insert when section missing (verify blank line separator); insert mas with id format; insert at beginning/middle/end of sorted section |
| skip-lists.sh | Cask in skip list; cask not in skip list; empty skip list; mas in skip list; ignored package; not ignored; missing ignore file |
| drift.sh | Zero drift (all tracked); formula drift; cask drift filtered by skip; mas drift filtered by skip; tap drift; brew command failure returns empty |
| cask-detect.sh | App artifact found; app artifact missing; uninstall artifact found; pkgutil receipt found; no artifacts; jq not available error; orphaned cask detection with bulk query |

**What does NOT get tested:**
- `lib/output.sh` — UI rendering is not worth testing in bash.
- Orchestrator scripts (bootstrap, brew-audit, brew-health, brew-skip-detect) — they depend on interactive prompts and live Homebrew state.
- `_adopt_cask`, `_remove_*` functions — these call destructive brew commands.

### Brewfile Changes

Two entries added:
```
brew 'bats-core'
brew 'jq'
```

Both inserted in alphabetical position within the `brew` section.

### Sourcing Convention

All four scripts currently source `lib/output.sh` with the same pattern (e.g., bootstrap lines 13–14):
```bash
# shellcheck source=lib/output.sh
source "$DOTFILES_ROOT/script/lib/output.sh"
```

New libraries follow the same pattern. Each script sources only what it needs:

| Script | Sources |
|--------|---------|
| bootstrap | output.sh, brewfile.sh, skip-lists.sh, drift.sh |
| brew-audit | output.sh, brewfile.sh, skip-lists.sh, drift.sh, cask-detect.sh |
| brew-health | output.sh, brewfile.sh, cask-detect.sh |
| brew-skip-detect | output.sh, brewfile.sh, skip-lists.sh, cask-detect.sh |

Libraries that depend on other libraries source them internally with double-source guards:
- `drift.sh` sources `brewfile.sh` and `skip-lists.sh`
- `cask-detect.sh` is standalone (only needs `jq`)

### File Size Targets

| File | Before | After | Change |
|------|--------|-------|--------|
| `lib/output.sh` | 883 | 883 | unchanged |
| `lib/brewfile.sh` | — | ~120 | new |
| `lib/drift.sh` | — | ~80 | new |
| `lib/skip-lists.sh` | — | ~35 | new |
| `lib/cask-detect.sh` | — | ~90 | new |
| `bootstrap` | 645 | ~400 | -245 |
| `brew-audit` | 551 | ~350 | -201 |
| `brew-health` | 387 | ~300 | -87 |
| `brew-skip-detect` | 284 | ~200 | -84 |
| **Total script/** | **2,750** | **~2,458** | **-292** |
| **Total test/** | — | ~350 | new |

Net reduction in script/ is modest (~300 lines) because the logic moves into libraries rather than disappearing. The real win is single-ownership: each piece of logic lives in exactly one place.

## Success Criteria

1. All four scripts produce identical user-facing behavior — same output format, same prompts, same exit codes, same CLI flags.
2. `bats test/` passes with all library tests green.
3. No orchestrator script exceeds 400 lines.
4. Zero duplication of: Brewfile section parsing, drift collection loops, skip-list filtering, or cask artifact detection logic.
5. Zero `python3 -c` calls remain in any script.
6. `jq` and `bats-core` are in the Brewfile.
7. Each new library has a double-source guard and shellcheck source directives.

## Risks

| Risk | Mitigation |
|------|------------|
| Behavioral regression in drift detection after extraction | bats tests cover all drift scenarios; manual smoke test of `script/bootstrap --dry-run` |
| `jq` not installed on existing machines | `jq` added to Brewfile; cask-detect.sh functions fail with clear error if jq missing |
| Sourcing order issues (library depends on another not yet loaded) | Libraries source their own dependencies with double-source guards |
| brew-skip-detect shell option leaking (currently saved/restored in bootstrap) | The save/restore pattern around `source brew-skip-detect` in bootstrap stays unchanged |
