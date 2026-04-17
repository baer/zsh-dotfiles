# Dependencies Phase UX Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the Dependencies phase so brew sub-steps render as indented children beneath a header that resolves with total timing after all sub-steps complete.

**Architecture:** Add substep output helpers to `output.sh` (indented spinners + line counter), add `phase_end_deferred` / `phase_resolve` to handle the cursor-rewrite pattern, then rewire `bootstrap` Phase 4 and `brew-skip-detect` to use them.

**Tech Stack:** Bash, ANSI escape sequences, existing output.sh helpers.

---

### Task 1: Add substep output functions to output.sh

**Files:**
- Modify: `script/lib/output.sh:525-577` (spinner section — add substep functions after spinner_stop)

- [ ] **Step 1: Add the substep state variable and three substep output functions**

Insert after the `_spinner_cleanup()` function (after line 591) and before the `run_with_spinner` section comment (line 593):

```bash
# ---------------------------------------------------------------------------
# Sub-step output (indented beneath a phase header)
# ---------------------------------------------------------------------------

_SUBSTEP_COUNT=0

substep_log_success() { printf "      %s %s\n" "$_CHECK" "$1"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_error()   { printf "      %s %s\n" "$_CROSS" "$1" >&2; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_warn()    { printf "      %s %s\n" "$_WARN"  "$1"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
substep_log_info()    { printf "      %s %s\n" "$_INFO"  "${_DIM}$1${_RST}"; _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1)); }
```

- [ ] **Step 2: Add substep_start function**

Insert immediately after the log functions from Step 1:

```bash
substep_start() {
  local message="$1"

  # Non-interactive: just print the message, no animation
  if [[ "$INTERACTIVE" != true ]] || ! _is_tty; then
    printf "      · %s\n" "$message"
    _SUBSTEP_COUNT=$((_SUBSTEP_COUNT + 1))
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
      printf "\r\e[2K      ${_CYAN}%s${_RST} %s%s" "${_SPINNER_FRAMES[$((i % ${#_SPINNER_FRAMES[@]}))]}" "$message" "$extra"
      i=$((i + 1))
      sleep 0.08
    done
  ) &
  _SPINNER_PID=$!
}
```

- [ ] **Step 3: Add substep_stop function**

Insert immediately after `substep_start`:

```bash
substep_stop() {
  local status="$1" message="$2"

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
    ok)   substep_log_success "$message" ;;
    fail) substep_log_error   "$message" ;;
    warn) substep_log_warn    "$message" ;;
    skip) substep_log_info    "$message" ;;
  esac
}
```

- [ ] **Step 4: Add run_with_substep_spinner and run_with_substep_streaming_spinner**

Insert immediately after `substep_stop`:

```bash
run_with_substep_spinner() {
  local message="$1" logfile="$2"
  shift 2

  substep_start "$message"
  if "$@" >> "$logfile" 2>&1; then
    substep_stop ok "$message"
    return 0
  else
    local rc=$?
    substep_stop fail "$message (see ${logfile##*/} for details)"
    return "$rc"
  fi
}

run_with_substep_streaming_spinner() {
  local message="$1" logfile="$2"
  shift 2

  substep_start "$message"

  local exit_code_file
  exit_code_file="$(mktemp "${TMPDIR:-/tmp}/.dotfiles_exit.XXXXXX")"

  {
    "$@" 2>&1 || echo $? > "$exit_code_file"
  } | while IFS= read -r line; do
    printf '%s\n' "$line" >> "$logfile"
    if [[ "$line" =~ ^(Installing|Upgrading|Using)[[:space:]]+(.+)$ ]]; then
      local pkg="${BASH_REMATCH[2]}"
      pkg="${pkg%%[[:space:]]*}"
      if [[ -n "$_SPINNER_STATUS_FILE" ]]; then
        printf '%s' "${BASH_REMATCH[1],,} ${pkg}" > "$_SPINNER_STATUS_FILE"
      fi
    fi
  done

  local rc=0
  if [[ -f "$exit_code_file" ]] && [[ -s "$exit_code_file" ]]; then
    rc="$(cat "$exit_code_file")"
  fi
  rm -f "$exit_code_file"

  if [[ $rc -eq 0 ]]; then
    substep_stop ok "$message"
  else
    substep_stop fail "$message (see ${logfile##*/} for details)"
  fi
  return "$rc"
}
```

- [ ] **Step 5: Verify syntax**

Run: `bash -n script/lib/output.sh`
Expected: no output (clean parse)

- [ ] **Step 6: Commit**

```bash
git add script/lib/output.sh
git commit -m "Add substep output functions for indented phase sub-steps"
```

---

### Task 2: Add phase_end_deferred and phase_resolve to output.sh

**Files:**
- Modify: `script/lib/output.sh:252-306` (phase_end section — add new functions after phase_end)

- [ ] **Step 1: Add phase_end_deferred function**

Insert after the `phase_end()` function (after line 306, before `phase_pause`):

```bash
# End the phase spinner but leave the header line in place (no ✓ yet).
# Sub-steps will print beneath it. Call phase_resolve() when done.
phase_end_deferred() {
  _SUBSTEP_COUNT=0

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    # Enforce minimum spin duration
    local elapsed=$((SECONDS - _ACTIVE_PHASE_START))
    if [[ $elapsed -lt 1 ]]; then
      sleep "$_PHASE_MIN_SPIN"
    fi

    # Kill spinner and clear line
    if [[ -n "${_SPINNER_PID:-}" ]]; then
      kill "$_SPINNER_PID" 2>/dev/null || true
      wait "$_SPINNER_PID" 2>/dev/null || true
      _SPINNER_PID=""
      printf "\r\e[2K"
    fi
    if [[ -n "${_SPINNER_STATUS_FILE:-}" ]]; then
      rm -f "$_SPINNER_STATUS_FILE"
      _SPINNER_STATUS_FILE=""
    fi

    # Print the phase name as a plain header (no status symbol yet)
    printf "  %s\n" "$_ACTIVE_PHASE_NAME"
  else
    # Non-TTY: already printed by phase_start, nothing to do
    :
  fi
}
```

- [ ] **Step 2: Add phase_resolve function**

Insert immediately after `phase_end_deferred`:

```bash
# Rewrite the deferred phase header with final status and timing.
# Must be called after all sub-steps have printed.
phase_resolve() {
  local status="$1" detail="$2"
  local name="$_ACTIVE_PHASE_NAME"
  local timing
  timing="$(_phase_timer_elapsed "$name")"

  if [[ "$INTERACTIVE" == true ]] && _is_tty; then
    local lines_to_jump=$_SUBSTEP_COUNT

    # Move cursor up to the header line, clear it, rewrite
    if [[ $lines_to_jump -gt 0 ]]; then
      printf "\e[%dA" "$((lines_to_jump + 1))"
    else
      printf "\e[1A"
    fi
    printf "\e[2K"

    local sym
    case "$status" in
      ok)   sym="$_CHECK" ;;
      fail) sym="$_CROSS" ;;
      warn) sym="$_WARN"  ;;
      skip) sym="$_SKIP"  ;;
    esac

    _format_status_row "$sym" "$name" "$detail" "$timing"
    printf '\n'

    # Move cursor back down to the bottom
    if [[ $lines_to_jump -gt 0 ]]; then
      printf "\e[%dB" "$lines_to_jump"
    fi
  else
    # Non-TTY: print a resolved summary line at the end
    local sym_text
    case "$status" in
      ok)   sym_text="$_CHECK" ;;
      fail) sym_text="$_CROSS" ;;
      warn) sym_text="$_WARN"  ;;
      skip) sym_text="$_SKIP"  ;;
    esac
    printf "  %s %s — %s  %s\n" "$sym_text" "$name" "$detail" "$timing"
  fi

  _ACTIVE_PHASE_NAME=""
  _ACTIVE_PHASE_NUMBER=""
  _ACTIVE_PHASE_START=0
  _SUBSTEP_COUNT=0
}
```

- [ ] **Step 3: Verify syntax**

Run: `bash -n script/lib/output.sh`
Expected: no output (clean parse)

- [ ] **Step 4: Commit**

```bash
git add script/lib/output.sh
git commit -m "Add phase_end_deferred and phase_resolve for nested phase headers"
```

---

### Task 3: Rewire bootstrap Phase 4 to use nested sub-steps

**Files:**
- Modify: `script/bootstrap:344-438` (Phase 4 Dependencies block)

- [ ] **Step 1: Replace the phase start and homebrew check block**

Replace lines 345-384 (from `_phase_timer_start "Dependencies"` through the end of the homebrew check `fi`) with:

```bash
  _phase_timer_start "Dependencies"

  if $VERBOSE; then
    log_phase "4/4" "Dependencies"
  else
    phase_start "4/4" "Dependencies"
    phase_end_deferred
  fi

  # --- Homebrew ---
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
      substep_log_success "homebrew"
    else
      log_skip "Homebrew already installed"
    fi
  fi
```

- [ ] **Step 2: Replace the brew update / upgrade / bundle block**

Replace lines 391-418 (from `# --- Brew update / upgrade / bundle ---` through the `fi`) with:

```bash
  # --- Brew update / upgrade / bundle ---
  if $VERBOSE; then
    log_info "brew update..."
    brew update 2>&1 | tee -a "$LOGFILE"
    log_success "brew update"

    log_info "brew upgrade..."
    brew upgrade 2>&1 | tee -a "$LOGFILE"
    log_success "brew upgrade"

    log_info "brew bundle..."
    brew bundle --file="$DOTFILES_ROOT/Brewfile" 2>&1 | tee -a "$LOGFILE"
    log_success "brew bundle"
  else
    run_with_substep_spinner "brew update" "$LOGFILE" \
      brew update

    # brew upgrade can "fail" (exit 1) when there's nothing to upgrade
    substep_start "brew upgrade"
    if brew upgrade >> "$LOGFILE" 2>&1; then
      substep_stop ok "brew upgrade"
    else
      substep_stop warn "brew upgrade (some packages skipped)"
    fi

    run_with_substep_streaming_spinner "brew bundle" "$LOGFILE" \
      brew bundle --file="$DOTFILES_ROOT/Brewfile"
  fi
```

- [ ] **Step 3: Replace the summary_add and install scripts block**

Replace lines 420-437 (from `summary_add ok "Dependencies"` through the install scripts `fi`) with:

```bash
  # --- Topic install scripts ---
  _install_count=0
  while IFS= read -r -d '' installer; do
    [[ "$installer" == *"homebrew/install.sh" ]] && continue  # already handled above
    if $VERBOSE; then
      log_info "Running ${installer#"$DOTFILES_ROOT"/}..."
      sh -c "$installer" 2>&1 | tee -a "$LOGFILE"
    else
      sh -c "$installer" >> "$LOGFILE" 2>&1
    fi
    _install_count=$((_install_count + 1))
  done < <(find "$DOTFILES_ROOT" -name install.sh -not -path '*.git*' -print0)

  if [[ $_install_count -gt 0 ]]; then
    if $VERBOSE; then
      log_success "$_install_count install scripts run"
    else
      substep_log_success "$_install_count install scripts run"
    fi
  fi

  if ! $VERBOSE; then
    phase_resolve ok "installed"
  fi

  summary_add ok "Dependencies" "installed" "$(_phase_timer_elapsed "Dependencies")"
```

- [ ] **Step 4: Verify syntax**

Run: `bash -n script/bootstrap`
Expected: no output (clean parse)

- [ ] **Step 5: Commit**

```bash
git add script/bootstrap
git commit -m "Rewire Dependencies phase to use nested sub-steps"
```

---

### Task 4: Update brew-skip-detect messaging

**Files:**
- Modify: `script/brew-skip-detect:30-33` (No casks path)
- Modify: `script/brew-skip-detect:46-49` (All managed path)
- Modify: `script/brew-skip-detect:59-61` (All in skip list path)
- Modify: `script/brew-skip-detect:68` (Checking N casks message)

- [ ] **Step 1: Silence the "no casks" and "all managed" paths**

Replace line 31:
```bash
  log_info "No casks found in Brewfile"
```
with:
```bash
  # Nothing to report — no casks in Brewfile
```

Replace line 48 (after the first edit shifts line numbers — search for the string):
```bash
  log_info "All Brewfile casks are already managed by Homebrew"
```
with:
```bash
  # Nothing to report — all casks are brew-managed
```

- [ ] **Step 2: Change the "all in skip list" message**

Replace line 60:
```bash
    log_info "All detected casks already in skip list"
```
with:
```bash
    substep_log_info "skipping casks installed outside Homebrew"
```

- [ ] **Step 3: Change the "checking N casks" message**

Replace line 68:
```bash
log_info "Checking ${#unmanaged_casks[@]} casks not managed by Homebrew..."
```
with:
```bash
substep_log_info "checking ${#unmanaged_casks[@]} casks not managed by Homebrew"
```

- [ ] **Step 4: Verify syntax**

Run: `bash -n script/brew-skip-detect`
Expected: no output (clean parse)

- [ ] **Step 5: Commit**

```bash
git add script/brew-skip-detect
git commit -m "Update brew-skip-detect messages for nested Dependencies UX"
```

---

### Task 5: Manual smoke test

**Files:** (none — verification only)

- [ ] **Step 1: Run bootstrap in dry-run/verbose mode to check syntax integration**

Run: `bash -n script/bootstrap && bash -n script/lib/output.sh && bash -n script/brew-skip-detect`
Expected: all three pass with no output

- [ ] **Step 2: Run bootstrap and visually verify nested output**

Run: `script/bootstrap`
Expected output pattern (TTY):
```
  ✓ Dependencies                                   Xs
      ✓ homebrew
      · skipping casks installed outside Homebrew
      ✓ brew update
      ✓ brew upgrade
      ✓ brew bundle
```

Verify:
- Header shows ✓ with total timing
- Sub-steps are indented 4 spaces deeper than header
- No double-printing of "Dependencies"
- Summary box still shows single rolled-up Dependencies line

- [ ] **Step 3: Commit any fixups if needed**

If anything required adjustment during smoke testing, commit fixes:
```bash
git add -u
git commit -m "Fix issues found during Dependencies UX smoke test"
```
