# Script Library Refactor — Design Spec

**Date:** 2026-04-20
**Scope:** `script/lib/` and the 4 main scripts in `script/`
**Goal:** Make the ~2,830-line script directory tight and robust by splitting the monolithic output library, deduplicating spinner/substep code, extracting shared adoption logic, and adding a check runner to brew-health.
**Constraint:** Zero behavioral changes. Every function keeps its exact signature. Every script produces identical output.

---

## 1. Split `output.sh` (883 lines) into 6 Focused Libraries

`output.sh` currently handles 6 unrelated concerns. Split along the existing `# ---` section boundaries.

### 1.1 `lib/term.sh` (~85 lines)

Terminal capability detection and visual primitives.

**Contains:**
- `_is_tty`, `_should_color`, `INTERACTIVE` auto-detection (current lines 18-32)
- Color variables: `_RST`, `_BOLD`, `_DIM`, `_RED`, `_GREEN`, `_YELLOW`, `_BLUE`, `_CYAN` (lines 38-49)
- Status symbols: `_CHECK`, `_CROSS`, `_WARN`, `_SKIP`, `_INFO` (lines 51-55)
- Box-drawing characters: `_BOX_TL`, `_BOX_TR`, `_BOX_BL`, `_BOX_BR`, `_BOX_H`, `_BOX_V`, `_BOX_DIV_L`, `_BOX_DIV_R`, `_BULLET`, `_BULLET_EMPTY` (lines 60-63)
- Box-drawing helpers: `_draw_box_top`, `_draw_box_bottom`, `_draw_box_divider`, `_draw_box_row` (lines 70-101)

**Depends on:** Nothing. Leaf of the dependency tree.

**Rationale:** Box-drawing primitives are visual atoms like colors. They're used by log.sh, phase.sh, and error.sh — putting them in term.sh avoids a separate tiny box.sh that everything would need to source.

### 1.2 `lib/log.sh` (~70 lines)

Simple status logging and header/footer display.

**Contains:**
- `log_success`, `log_error`, `log_warn`, `log_skip`, `log_info` (lines 146-150)
- `log_header` (lines 156-199)
- `log_celebration` (lines 523-529)

**Depends on:** `term.sh`

**Rationale:** Most-called functions in the codebase. Every script uses these. A lightweight script that only needs logging can source `term.sh` + `log.sh` (~155 lines total) instead of the full 883-line output.sh.

### 1.3 `lib/spinner.sh` (~130 lines)

All spinner and substep animation, deduplicated. See Section 2 for deduplication details.

**Contains:**
- State: `_SPINNER_PID`, `_SPINNER_FRAMES`, `_SPINNER_STATUS_FILE`
- Internal: `_spinner_start_impl(message, indent)`, `_spinner_stop_impl(status, message, indent)`, `_spinner_cleanup`
- Public spinner API: `spinner_start(message)`, `spinner_stop(status, message)` — thin wrappers with 2-space indent
- Substep state: `_SUBSTEP_COUNT`, `_SUBSTEP_CURSOR_DIRTY`
- Substep API: `substep_start(message)`, `substep_stop(status, message)` — thin wrappers with 6-space indent + count tracking
- Substep logging: `substep_log_success`, `substep_log_error`, `substep_log_warn`, `substep_log_info`, `substep_mark_dirty`
- Runners: `run_with_substep_spinner(message, logfile, cmd...)`, `run_with_substep_streaming_spinner(message, logfile, cmd...)`

**Depends on:** `term.sh`

### 1.4 `lib/prompt.sh` (~50 lines)

Interactive user input.

**Contains:**
- `prompt_user(question, default)` (lines 837-849)
- `prompt_choice(question, choices...)` (lines 853-883)

**Depends on:** `term.sh`

### 1.5 `lib/phase.sh` (~340 lines)

Phase lifecycle system and structured summary display.

**Contains:**
- Column formatting: `_COL_LABEL`, `_COL_DETAIL`, `_COL_TIMING`, `_pad_to_width(width, string)`, `_format_status_row(sym, label, detail, timing)` (lines 107-140)
- Phase state: `_PHASE_START_TIMES`, `_PHASE_TOTAL`, `_PHASE_CURRENT`, `_ACTIVE_PHASE_NAME`, `_ACTIVE_PHASE_NUMBER`, `_ACTIVE_PHASE_START`, `_PHASE_MIN_SPIN`
- Phase timers: `_phase_timer_start(name)`, `_phase_timer_elapsed(name)` (lines 213-223)
- Phase API: `phase_start(number, name)`, `phase_update(text)`, `phase_end(status, detail)`, `phase_end_deferred()`, `phase_resolve(status, detail)`, `phase_pause()`, `phase_resume()`, `log_phase(number, name)` (lines 226-433)
- `log_summary_box(statuses, labels, details, timings, total_time)` (lines 441-517)

**Depends on:** `term.sh`, `spinner.sh`

**Rationale:** Largest new file at ~340 lines. Phase lifecycle, column formatting, and summary box are coupled through `_format_status_row`, `_pad_to_width`, and column width constants. Splitting further creates cross-file coupling worse than one cohesive file.

### 1.6 `lib/error.sh` (~115 lines)

Error context display with pattern-matched hints.

**Contains:**
- `log_error_context(logfile, phase)` (lines 535-587)
- `_detect_error_hint(text)` (lines 589-646)

**Depends on:** `term.sh`

**Rationale:** Self-contained. Only used by bootstrap's `ERR` trap. Separating it makes the hint pattern list easy to find and extend.

### 1.7 `output.sh` Backward-Compatible Shim

`output.sh` becomes a thin shim (~15 lines) that sources all 6 files:

```bash
#!/usr/bin/env bash
# output.sh — backward-compatible shim
# Sources all output sub-libraries. New scripts should source individual libs.
[[ -n "${_OUTPUT_SH_LOADED:-}" ]] && return 0 2>/dev/null || true
_OUTPUT_SH_LOADED=1
_OUTPUT_SH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_OUTPUT_SH_DIR/term.sh"
source "$_OUTPUT_SH_DIR/log.sh"
source "$_OUTPUT_SH_DIR/spinner.sh"
source "$_OUTPUT_SH_DIR/prompt.sh"
source "$_OUTPUT_SH_DIR/phase.sh"
source "$_OUTPUT_SH_DIR/error.sh"
```

Keeps the `_OUTPUT_SH_LOADED` source guard so existing scripts that source output.sh still work without changes during migration.

### Dependency Graph

```
term.sh  (no dependencies)
  |-- log.sh
  |-- spinner.sh
  |-- prompt.sh
  |-- phase.sh --> spinner.sh
  +-- error.sh
```

No circular dependencies. Source guards in each file prevent double-loading.

---

## 2. Spinner/Substep Deduplication

### Problem

`spinner_start` (26 lines) and `substep_start` (27 lines) are near-identical — the only difference is printf indent (`"  "` vs `"      "`). Same for `spinner_stop` (22 lines) vs `substep_stop` (22 lines), with indent and which log functions they call.

### Solution

Extract `_spinner_start_impl(message, indent)` and `_spinner_stop_impl(status, message, indent)` as parameterized internals. Public functions become thin wrappers:

```bash
_spinner_start_impl() {
  local message="$1" indent="$2"
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "%s· %s\n" "$indent" "$message"
    return
  fi
  _SPINNER_STATUS_FILE="$(mktemp "${TMPDIR:-/tmp}/.dotfiles_spinner.XXXXXX")"
  (
    trap 'exit 0' TERM
    local i=0
    while true; do
      local extra=""
      if [[ -f "$_SPINNER_STATUS_FILE" ]] && [[ -s "$_SPINNER_STATUS_FILE" ]]; then
        extra=" ${_DIM}· $(cat "$_SPINNER_STATUS_FILE")${_RST}"
      fi
      printf "\r\e[2K%s${_CYAN}%s${_RST} %s%s" "$indent" "${_SPINNER_FRAMES[$((i % ${#_SPINNER_FRAMES[@]}))]}" "$message" "$extra"
      i=$((i + 1))
      sleep 0.08
    done
  ) &
  _SPINNER_PID=$!
}

_spinner_stop_impl() {
  local status="$1" message="$2" indent="$3"
  if [[ -n "$_SPINNER_PID" ]]; then
    kill "$_SPINNER_PID" 2>/dev/null || true
    wait "$_SPINNER_PID" 2>/dev/null || true
    _SPINNER_PID=""
    printf "\r\e[2K"
  fi
  if [[ -n "$_SPINNER_STATUS_FILE" ]]; then
    rm -f "$_SPINNER_STATUS_FILE"
    _SPINNER_STATUS_FILE=""
  fi
  case "$status" in
    ok)   printf "%s%s %s\n" "$indent" "$_CHECK" "$message" ;;
    fail) printf "%s%s %s\n" "$indent" "$_CROSS" "$message" >&2 ;;
    warn) printf "%s%s %s\n" "$indent" "$_WARN"  "$message" ;;
    skip) printf "%s%s %s\n" "$indent" "$_SKIP"  "${_DIM}$message${_RST}" ;;
  esac
}

spinner_start() { _spinner_start_impl "$1" "  "; }
spinner_stop()  { _spinner_stop_impl "$1" "$2" "  "; }

substep_start() {
  _spinner_start_impl "$1" "      "
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1))
  fi
}

substep_stop() {
  _spinner_stop_impl "$1" "$2" "      "
  _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1))
}
```

### What stays unchanged
- `substep_log_success/error/warn/info` — already one-liners, no duplication
- `run_with_substep_spinner`, `run_with_substep_streaming_spinner` — unique logic, call substep_start/stop so they benefit automatically
- `_spinner_cleanup` — already has one copy
- All public function signatures — callers don't change

### Impact
~45 lines of duplicated animation/cleanup code eliminated.

---

## 3. New `lib/adopt.sh` — Shared Cask Adoption Logic

### Problem

`brew-audit` `_adopt_cask` (lines 116-168) and `brew-skip-detect` (lines 122-165) both implement "check if app is running -> prompt to quit -> trash to ~/.Trash" with slightly different flows.

### Solution

Extract shared primitives into `lib/adopt.sh` (~100 lines). Keep high-level orchestration in each script.

### Functions

```bash
# _app_is_running app_base_name
# Returns 0 if a process matching the name is found.
_app_is_running() {
  local app_base="$1"
  pgrep -fi "$app_base" > /dev/null 2>&1
}

# _prompt_quit_app app_base_name
# Warns that the app is running, prompts user to quit it.
# Returns 0 if safe to proceed, 1 if user chose to skip or app still running.
_prompt_quit_app() {
  local app_base="$1"
  log_warn "$app_base is running. Please quit it before continuing."
  printf "    Press Enter when ready, or 's' to skip... "
  local response
  read -r response
  [[ "$response" == "s" ]] && return 1
  if _app_is_running "$app_base"; then
    log_error "$app_base is still running — skipping"
    return 1
  fi
  return 0
}

# _trash_app app_path
# Moves an .app bundle to Trash. Returns 0 on success, 1 on failure.
# No-op (returns 0) if the path doesn't exist.
_trash_app() {
  local app_path="$1"
  [[ -d "$app_path" ]] || return 0
  if mv "$app_path" "$HOME/.Trash/" 2>/dev/null; then
    return 0
  else
    log_error "Could not move $(basename "$app_path") to Trash (permissions?)"
    return 1
  fi
}

# _remove_from_skip_list cask
# Removes a cask from HOMEBREW_BUNDLE_CASK_SKIP in ~/.localrc.
# Moved verbatim from brew-audit lines 91-111.
_remove_from_skip_list() {
  local cask="$1"
  local localrc="$HOME/.localrc"
  [[ -z "${HOMEBREW_BUNDLE_CASK_SKIP:-}" ]] && return 0
  local new_skip
  new_skip="$(echo "$HOMEBREW_BUNDLE_CASK_SKIP" | tr ' ' '\n' | grep -vx "$cask" | tr '\n' ' ' | sed 's/ $//')"
  if [[ -f "$localrc" ]] && grep -q "HOMEBREW_BUNDLE_CASK_SKIP" "$localrc"; then
    if [[ -z "$new_skip" ]]; then
      sed -i '' '/^export HOMEBREW_BUNDLE_CASK_SKIP=/d' "$localrc"
    else
      sed -i '' "s|^export HOMEBREW_BUNDLE_CASK_SKIP=.*|export HOMEBREW_BUNDLE_CASK_SKIP=\"$new_skip\"|" "$localrc"
    fi
  fi
  export HOMEBREW_BUNDLE_CASK_SKIP="$new_skip"
}

# _adopt_cask cask app_name
# Full adoption: check running -> prompt -> trash -> brew install -> Brewfile -> skip list.
# Requires LOGFILE and BREWFILE to be set by the caller.
# Returns 0 on success, 1 on skip/failure.
_adopt_cask() {
  local cask="$1" app_name="$2"
  local app_base="${app_name%.app}"

  if _app_is_running "$app_base"; then
    _prompt_quit_app "$app_base" || { log_info "Skipped $cask"; return 1; }
  fi

  _trash_app "/Applications/$app_name" || { log_info "Skipping adoption of $cask"; return 1; }

  spinner_start "brew install --cask $cask"
  if brew install --cask "$cask" >> "$LOGFILE" 2>&1; then
    spinner_stop ok "brew install --cask $cask"
  else
    spinner_stop fail "brew install --cask $cask (see log for details)"
    return 1
  fi

  if ! grep -qx "cask '$cask'" "$BREWFILE"; then
    _brewfile_insert "cask" "$cask"
  fi

  _remove_from_skip_list "$cask"
  return 0
}
```

**Depends on:** `term.sh`, `log.sh`, `spinner.sh`, `brewfile.sh`

### Impact on Main Scripts

**`brew-audit`:** Drops `_adopt_cask` (~53 lines) and `_remove_from_skip_list` (~21 lines). Sources `adopt.sh`. Net: ~-70 lines.

**`brew-skip-detect`:** Replaces inline adoption logic (lines 122-165, ~44 lines) with calls to `_app_is_running`, `_prompt_quit_app`, `_trash_app`. The pkg: detection special case stays inline (specific to skip-detect). Net: ~-30 lines.

---

## 4. `brew-health` Check Runner

### Problem

The bottom of brew-health manually lists each check call with `|| true`. Adding a new check requires remembering to add the boilerplate in the right position.

### Solution

Registry-style runner. The 8 check functions stay exactly as-is — each has unique logic that doesn't benefit from templating.

```bash
_HEALTH_CHECKS=(
  _check_brew_reachable       # gate — failure skips remaining checks
  _check_update_lock
  _check_fsmonitor_taps
  _check_obsolete_taps
  _check_disabled_formulae
  _check_orphaned_casks
  _check_bundle_satisfaction
  _check_vulnerable_formulae
)

printf "\n  ${_BOLD}brew-health${_RST}\n\n"

for check in "${_HEALTH_CHECKS[@]}"; do
  if ! "$check"; then
    # First check is a gate — if Homebrew isn't reachable, stop
    if [[ "$check" == "${_HEALTH_CHECKS[0]}" ]]; then
      printf "\n  ${_RED}${_BOLD}1 issue found${_RST} (Homebrew not reachable — remaining checks skipped)\n\n"
      exit 1
    fi
  fi
done

if [[ $_failures -eq 0 ]]; then
  printf "\n  ${_GREEN}${_BOLD}All checks passed${_RST}\n\n"
  exit 0
else
  printf "\n  ${_RED}${_BOLD}%d issue(s) found${_RST}\n\n" "$_failures"
  exit 1
fi
```

### What doesn't change
- All 8 `_check_*` functions stay exactly as written
- `_check_pass`, `_check_fail`, `_check_detail` stay local to brew-health (no other script uses them)
- `_failures` counter stays local

### Impact
~10 lines saved. The real value: adding a new health check is a one-line change (append to `_HEALTH_CHECKS` array).

---

## 5. Updated Source Dependencies

After migration, each script sources only what it needs:

| Script | Sources |
|---|---|
| `bootstrap` | `term.sh`, `log.sh`, `spinner.sh`, `prompt.sh`, `phase.sh`, `error.sh`, `brewfile.sh`, `skip-lists.sh`, `drift.sh` |
| `brew-audit` | `term.sh`, `log.sh`, `spinner.sh`, `prompt.sh`, `brewfile.sh`, `skip-lists.sh`, `drift.sh`, `cask-detect.sh`, `adopt.sh` |
| `brew-health` | `term.sh`, `brewfile.sh`, `cask-detect.sh` |
| `brew-skip-detect` | `term.sh`, `log.sh`, `spinner.sh`, `prompt.sh`, `brewfile.sh`, `skip-lists.sh`, `cask-detect.sh`, `adopt.sh` |

Key win: `brew-health` sources ~85 lines of output code (term.sh) instead of 883 (output.sh). It only needs color variables and symbols for its local `_check_pass`/`_check_fail`/`_check_detail` helpers.

---

## 6. File Inventory After Refactor

### Libraries (`script/lib/`)

| File | Lines (est.) | Purpose |
|---|---|---|
| `term.sh` | ~85 | Terminal detection, colors, symbols, box-drawing primitives |
| `log.sh` | ~70 | Status logging, header, celebration |
| `spinner.sh` | ~130 | Spinner/substep animation (deduplicated) |
| `prompt.sh` | ~50 | Interactive user input |
| `phase.sh` | ~340 | Phase lifecycle, column formatting, summary box |
| `error.sh` | ~115 | Error context display, hint detection |
| `adopt.sh` | ~100 | Cask adoption primitives and full adoption flow |
| `brewfile.sh` | ~88 | Brewfile parsing and mutation (unchanged) |
| `drift.sh` | ~110 | Package drift collection (unchanged) |
| `cask-detect.sh` | ~127 | Cask artifact detection via jq (unchanged) |
| `skip-lists.sh` | ~32 | Skip list and ignore predicates (unchanged) |
| `output.sh` | ~15 | Backward-compatible shim (sources all 6 new libs) |

### Main Scripts (`script/`)

| File | Lines (est.) | Change |
|---|---|---|
| `bootstrap` | ~570 | Minor reduction from lib source changes |
| `brew-audit` | ~350 | -70 lines from extracting adopt/skip-list logic |
| `brew-health` | ~350 | -15 lines from runner pattern |
| `brew-skip-detect` | ~175 | -40 lines from using adopt.sh primitives |

### Totals

| Metric | Before | After |
|---|---|---|
| Total lines | ~2,830 | ~2,680 |
| Largest lib | 883 (`output.sh`) | ~340 (`phase.sh`) |
| Lib files | 5 | 12 (including shim) |
| Duplicated spinner code | ~49 lines | 0 |
| Copies of adoption logic | 2 | 1 |

---

## 7. Risk Assessment

**Low risk:**
- Every split follows an existing `# ---` section boundary in output.sh
- Source guards prevent double-loading
- output.sh shim provides backward compatibility
- No function signatures change
- No behavioral changes

**Watch for:**
- Variable scoping: globals like `_SPINNER_PID` must be accessible across the boundary between spinner.sh and phase.sh. Both are sourced into the same shell, so this works — but verify in testing.
- Source order: phase.sh depends on spinner.sh. Scripts must source spinner.sh before phase.sh (or use the output.sh shim which handles order).
- The `_adopt_cask` extraction requires LOGFILE and BREWFILE to be set by the caller. Both brew-audit and brew-skip-detect already set these at the top of the script.
- `brewfile.sh` has an implicit dependency on `log.sh`: its `_brewfile_insert` function calls `log_success`. Currently this works because all callers source `output.sh` first. After the split, `brewfile.sh` should explicitly `source log.sh` (which sources `term.sh` via its own guard). Read-only functions (`_brewfile_list_section`, `_brewfile_contains`) don't have this dependency, so scripts like `brew-health` that only use read functions won't trigger the issue — but making the dependency explicit is cleaner.

---

## 8. Verification Plan

After each implementation step:
1. Run `zsh -n` on any modified `.zsh` files (PostToolUse hook handles this)
2. Run `shellcheck` on any modified `bin/*` scripts (PostToolUse hook handles this)
3. Run `bash -n script/lib/*.sh` to syntax-check all libraries
4. Run `bash -n script/bootstrap script/brew-audit script/brew-health script/brew-skip-detect` to syntax-check all main scripts
5. Run `script/bootstrap --dry-run` to verify the preflight path still works
6. Run `script/brew-health` to verify health checks still execute and produce identical output
7. Verify `source script/lib/output.sh` still loads all functionality (shim works)
