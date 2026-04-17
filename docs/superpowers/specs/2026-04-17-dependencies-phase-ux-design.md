# Dependencies Phase UX Redesign

## Problem

The bootstrap script's Phase 4 (Dependencies) has three UX issues:

1. The "Dependencies" header resolves with a checkmark almost immediately, but the actual dependency work (brew update/upgrade/bundle) follows as separate flat lines — implying the phase is done before it starts.
2. The info message "All detected casks already in skip list" is jargon. Users unfamiliar with `HOMEBREW_BUNDLE_CASK_SKIP` won't understand it.
3. brew update/upgrade/bundle appear at the same visual level as the Dependencies header. The UX implies these should be sub-steps, but they're rendered as peers.

## Design

### Visual Layout

Dependencies becomes a nested phase: a header line with indented sub-steps beneath it.

**TTY (interactive) — final resolved state:**

```
  ✓ Dependencies                                   47s
      ✓ homebrew                                    <1s
      · skipping casks installed outside Homebrew
      ✓ brew update                                  3s
      ✓ brew upgrade                                12s
      ✓ brew bundle                                 30s
      ✓ 2 install scripts run
```

- Header starts as a spinner (`⠋ Dependencies`), stays on screen.
- Sub-steps are indented 4 extra spaces (6 total from left margin vs 2 for phases).
- When all sub-steps complete, cursor jumps back to the header line and rewrites it with ✓ + total elapsed time.
- The summary box still shows the single rolled-up `✓ Dependencies  installed  47s` line.

**Non-TTY fallback (CI, piped output):**

```
  Dependencies
      ✓ homebrew
      · skipping casks installed outside Homebrew
      ✓ brew update   3s
      ✓ brew upgrade  12s
      ✓ brew bundle   30s
  ✓ Dependencies  47s
```

No cursor tricks. Header prints first as a plain label, resolved summary prints at the end.

### Cursor Rewrite Mechanics

A variable `_DEP_SUBSTEP_COUNT` tracks lines printed beneath the header. After all sub-steps complete:

1. Move cursor up N lines (`\e[${n}A`)
2. Clear the line (`\e[2K`)
3. Print the resolved header with ✓ and total timing via `_format_status_row`
4. Move cursor back down (`\e[${n}B`)

This only applies in TTY+interactive mode.

### New Functions in output.sh

**Sub-step helpers (indented output at 6 spaces):**

- `substep_start(msg)` — like `spinner_start` but at 6-space indent; increments `_DEP_SUBSTEP_COUNT`
- `substep_stop(status, msg [, timing])` — like `spinner_stop` but at 6-space indent with optional timing; increments counter
- `substep_info(msg)` — like `log_info` but at 6-space indent; increments counter

**Phase-level additions:**

- `phase_end_deferred()` — kills the phase spinner, leaves the header line on screen without ✓, records position
- `phase_resolve(status, detail)` — cursor-jumps back to header, rewrites it with final status + timing, returns cursor to bottom

### Changes to bootstrap (Phase 4 block)

Replace the current flat structure:

```bash
phase_start "4/4" "Dependencies"
phase_update "checking homebrew"
# ...
phase_end ok "homebrew ✓"       # "finishes" the phase immediately
# ... flat spinner lines for brew update/upgrade/bundle ...
```

With nested structure:

```bash
phase_start "4/4" "Dependencies"
phase_end_deferred               # kill spinner, leave header

substep_start "homebrew"
# ... check/install ...
substep_stop ok "homebrew"

# cask skip detection (uses substep_info for messages)

substep_start "brew update"
# ...
substep_stop ok "brew update"

# ... same for upgrade, bundle, install scripts ...

phase_resolve ok "installed"     # rewrite header with ✓ + total time
```

### brew-skip-detect Messaging Changes

| Current message | New message |
|---|---|
| `"All detected casks already in skip list"` | `"skipping casks installed outside Homebrew"` |
| `"No casks found in Brewfile"` | (silent) |
| `"All Brewfile casks are already managed by Homebrew"` | (silent) |

The script's `log_info` calls become `substep_info` calls so they render at the correct indent level. Since `brew-skip-detect` is `source`d into bootstrap (which already sources `output.sh`), the new functions are available without additional imports. The two "nothing to do" paths become silent since there's nothing useful to tell the user.

When casks are detected and the interactive prompt fires, that output stays as-is (it's already its own interactive flow separate from the phase system).

### Error Handling

- If a sub-step fails (e.g., `brew update` returns non-zero), `substep_stop fail` prints the failure at the indented level. `phase_resolve` still fires with `fail` status so the header shows ✗.
- The existing `_on_error` trap and log-tail display are unchanged.

### Scope

- Only Phase 4 (Dependencies) changes. Phases 1-3 remain single-line.
- Verbose mode (`--verbose`) is unchanged — it already prints flat `log_info`/`log_success` lines.
- The summary box is unchanged.
