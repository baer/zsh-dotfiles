# Dotfiles Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add cross-platform support, npm globals list, XDG base directories, and macOS keyboard repeat defaults to the zsh-dotfiles project.

**Architecture:** Four independent improvements layered onto the existing topic-directory structure. Cross-platform goes first (changes bootstrap structure). XDG goes second (renames starship symlink). Package lists and macOS defaults are independent and can be parallel.

**Tech Stack:** zsh, sh (POSIX), Homebrew, npm, macOS `defaults` command

**Spec:** `docs/superpowers/specs/2026-04-17-dotfiles-improvements-design.md`

---

## File Map

**New files:**
- `system/platform.zsh` — `is_macos`/`is_linux` helper functions
- `system/env.zsh` — XDG base directory exports
- `node/npm-globals.txt` — declarative list of global npm packages
- `node/install.sh` — installs npm globals from the list
- `starship/install.sh` — symlinks starship config to XDG location
- `macos/defaults.sh` — macOS `defaults write` commands
- `macos/install.sh` — runs defaults.sh during bootstrap
- `.claude/rules/macos.md` — rule file for macOS defaults convention
- `.claude/rules/xdg.md` — rule file for XDG policy

**Renamed files:**
- `starship/starship.symlink` -> `starship/config`

**Modified files:**
- `homebrew/path.zsh` — add platform guard
- `node/path.zsh` — add platform guard
- `pg/path.zsh` — add platform guard
- `system/grc.zsh` — add platform guard
- `zsh/zshrc.symlink` — guard Homebrew plugin sourcing
- `zsh/prompt.zsh` — update STARSHIP_CONFIG path
- `script/bootstrap` — separate install scripts from macOS-only block
- `AGENTS.md` — architecture updates
- `.claude/rules/shell-scripts.md` — mention platform helpers
- `.claude/rules/symlink.md` — note XDG alternative

---

### Task 1: Platform Detection Helpers

**Files:**
- Create: `system/platform.zsh`

- [ ] **Step 1: Create `system/platform.zsh`**

```zsh
# Platform detection helpers
# Available to all *.zsh files (loaded in the *.zsh pass).
# NOT available in path.zsh files (they load earlier) — use inline uname checks there.
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
```

- [ ] **Step 2: Verify syntax**

Run: `zsh -n system/platform.zsh`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add system/platform.zsh
git commit -m "Add is_macos/is_linux platform detection helpers"
```

---

### Task 2: Platform Guards on path.zsh Files

**Files:**
- Modify: `homebrew/path.zsh`
- Modify: `node/path.zsh`
- Modify: `pg/path.zsh`

These files load in the `path.zsh` pass (before `system/platform.zsh`), so they must use inline `uname` checks, not the `is_macos` helper.

- [ ] **Step 1: Guard `homebrew/path.zsh`**

Add to the top of the file, before the existing content:

```zsh
[[ "$(uname -s)" == "Darwin" ]] || return 0

```

The file becomes:

```zsh
[[ "$(uname -s)" == "Darwin" ]] || return 0

export HOMEBREW_PREFIX="/opt/homebrew"
export PATH="$HOMEBREW_PREFIX/bin:$PATH"
```

- [ ] **Step 2: Guard `node/path.zsh`**

Add to the top of the file, before the existing content:

```zsh
[[ "$(uname -s)" == "Darwin" ]] || return 0

```

The file becomes:

```zsh
[[ "$(uname -s)" == "Darwin" ]] || return 0

# Export globally installed npm scripts
export PATH="$HOMEBREW_PREFIX/share/npm/bin:$PATH"
```

- [ ] **Step 3: Guard `pg/path.zsh`**

Add to the top of the file, before the existing content:

```zsh
[[ "$(uname -s)" == "Darwin" ]] || return 0

```

The file becomes:

```zsh
[[ "$(uname -s)" == "Darwin" ]] || return 0

# Add the latest Homebrew-installed PostgreSQL to PATH
local pg_dirs=(/opt/homebrew/opt/postgresql@*(nOn))
[[ -n "$pg_dirs" ]] && export PATH="${pg_dirs[1]}/bin:$PATH"
```

- [ ] **Step 4: Verify syntax on all three files**

Run: `zsh -n homebrew/path.zsh && zsh -n node/path.zsh && zsh -n pg/path.zsh && echo "OK"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add homebrew/path.zsh node/path.zsh pg/path.zsh
git commit -m "Add platform guards to path.zsh files for Linux compatibility"
```

---

### Task 3: Platform Guards on *.zsh Files and zshrc

**Files:**
- Modify: `system/grc.zsh`
- Modify: `zsh/zshrc.symlink`

- [ ] **Step 1: Guard `system/grc.zsh`**

Replace the entire content of `system/grc.zsh` with:

```zsh
# GRC colorizes nifty unix tools all over the place
if is_macos && (( $+commands[grc] )) && (( $+commands[brew] ))
then
  source $HOMEBREW_PREFIX/etc/grc.zsh
fi
```

- [ ] **Step 2: Guard Homebrew plugin sourcing in `zsh/zshrc.symlink`**

Replace lines 54-61 (the Homebrew plugin block) with:

```zsh
# zsh plugins (from Homebrew)
if [[ -n "$HOMEBREW_PREFIX" ]]; then
  # autosuggestions: inline Fish-like suggestions from history
  [[ -f $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] \
    && source $HOMEBREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh

  # syntax-highlighting: colors commands as you type (must be sourced last)
  [[ -f $HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]] \
    && source $HOMEBREW_PREFIX/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
fi
```

- [ ] **Step 3: Verify syntax**

Run: `zsh -n system/grc.zsh && zsh -n zsh/zshrc.symlink && echo "OK"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add system/grc.zsh zsh/zshrc.symlink
git commit -m "Guard Homebrew-dependent shell config for Linux compatibility"
```

---

### Task 4: Bootstrap — Separate Install Scripts from macOS Block

**Files:**
- Modify: `script/bootstrap`

The current bootstrap runs all `install.sh` scripts inside the `$IS_MACOS` block (Phase 4, lines 439-457). Extract the install script loop so it runs on all platforms, after the macOS-only Homebrew section.

- [ ] **Step 1: Restructure Phase 4 in `script/bootstrap`**

Replace the section from `# --- Topic install scripts ---` (line 438) through the end of the install script loop (line 457, before `if ! $VERBOSE; then`) with nothing — remove it from inside the macOS block.

Then, after the closing `fi` of the `if $SKIP_DEPS / elif ! $IS_MACOS / else` block (currently the last line of Phase 4), add a new Phase 5 section:

```bash
# ---------------------------------------------------------------------------
# Phase 5: Topic Install Scripts
# ---------------------------------------------------------------------------

_current_phase="Install Scripts"

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
    log_success "install scripts ($_install_count)"
  else
    substep_log_success "install scripts ($_install_count)"
  fi
fi
```

Also update the phase labels: change `"1/4"` to `"1/5"`, `"2/4"` to `"2/5"`, `"3/4"` to `"3/5"`, `"4/4"` to `"4/5"`. The dry-run output should also reflect the new phase count.

- [ ] **Step 2: Verify bootstrap parses**

Run: `bash -n script/bootstrap && echo "OK"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add script/bootstrap
git commit -m "Run topic install scripts on all platforms, not just macOS"
```

---

### Task 5: XDG Base Directory Exports

**Files:**
- Create: `system/env.zsh`

- [ ] **Step 1: Create `system/env.zsh`**

```zsh
# XDG Base Directory Specification
# https://specifications.freedesktop.org/basedir-spec/latest/
# Uses :- so existing values (company tooling, Linux distro) are preserved.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
```

- [ ] **Step 2: Verify syntax**

Run: `zsh -n system/env.zsh`
Expected: no output (clean parse)

- [ ] **Step 3: Commit**

```bash
git add system/env.zsh
git commit -m "Export XDG base directory env vars"
```

---

### Task 6: Starship Migration to XDG

**Files:**
- Rename: `starship/starship.symlink` -> `starship/config`
- Create: `starship/install.sh`
- Modify: `zsh/prompt.zsh`

- [ ] **Step 1: Rename the starship config file**

```bash
git mv starship/starship.symlink starship/config
```

- [ ] **Step 2: Create `starship/install.sh`**

```sh
#!/bin/sh
# Symlink starship config to XDG location
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
src="$(cd "$(dirname "$0")" && pwd)/config"
dst="$config_home/starship.toml"

# Migrate: remove old ~/.starship symlink if it points to the old location
if [ -L "$HOME/.starship" ]; then
  rm "$HOME/.starship"
fi

mkdir -p "$config_home"

if [ -L "$dst" ]; then
  current="$(readlink "$dst")"
  if [ "$current" = "$src" ]; then
    exit 0  # already correct
  fi
fi

ln -sf "$src" "$dst"
```

Run: `chmod +x starship/install.sh`

- [ ] **Step 3: Update `zsh/prompt.zsh`**

Replace line 1:

```zsh
export STARSHIP_CONFIG=~/.starship
```

with:

```zsh
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
```

- [ ] **Step 4: Verify syntax**

Run: `zsh -n zsh/prompt.zsh && sh -n starship/install.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add starship/config starship/install.sh zsh/prompt.zsh
git commit -m "Move starship config to XDG location"
```

---

### Task 7: npm Globals List and Install Script

**Files:**
- Create: `node/npm-globals.txt`
- Create: `node/install.sh`

- [ ] **Step 1: Create `node/npm-globals.txt`**

```
yarn
pnpm
```

- [ ] **Step 2: Create `node/install.sh`**

```sh
#!/bin/sh
# Install global npm packages from npm-globals.txt
if ! command -v npm >/dev/null 2>&1; then
  exit 0
fi

dir="$(cd "$(dirname "$0")" && pwd)"

while IFS= read -r pkg || [ -n "$pkg" ]; do
  # Strip comments and whitespace
  pkg=$(echo "$pkg" | sed 's/#.*//' | tr -d '[:space:]')
  [ -z "$pkg" ] && continue
  if ! npm list -g --depth=0 "$pkg" >/dev/null 2>&1; then
    npm install -g "$pkg"
  fi
done < "$dir/npm-globals.txt"
```

Run: `chmod +x node/install.sh`

- [ ] **Step 3: Verify install script parses**

Run: `sh -n node/install.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add node/npm-globals.txt node/install.sh
git commit -m "Add npm globals list with yarn and pnpm"
```

---

### Task 8: macOS Defaults

**Files:**
- Create: `macos/defaults.sh`
- Create: `macos/install.sh`

- [ ] **Step 1: Create `macos/defaults.sh`**

```sh
#!/bin/sh
# macOS sensible defaults
# Run manually: sh macos/defaults.sh
# Re-run after macOS updates (updates can reset these).

[ "$(uname -s)" = "Darwin" ] || exit 0

# Keyboard: fast key repeat rate
# KeyRepeat: lower = faster (default 6, minimum 1)
# InitialKeyRepeat: lower = shorter delay before repeat (default 68, minimum 15)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15
```

Run: `chmod +x macos/defaults.sh`

- [ ] **Step 2: Create `macos/install.sh`**

```sh
#!/bin/sh
# Apply macOS defaults during bootstrap
if [ "$(uname -s)" = "Darwin" ]; then
  dir="$(cd "$(dirname "$0")" && pwd)"
  sh "$dir/defaults.sh"
fi
```

Run: `chmod +x macos/install.sh`

- [ ] **Step 3: Verify both scripts parse**

Run: `sh -n macos/defaults.sh && sh -n macos/install.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add macos/defaults.sh macos/install.sh
git commit -m "Add macOS defaults for fast keyboard repeat rate"
```

---

### Task 9: Documentation Updates — AGENTS.md

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update Architecture section**

After the existing loading order list (lines 7-13), add a new item between items 3 and 4:

The updated list should read:

```markdown
1. `~/.localrc` (if exists) -- secrets and machine-specific config
2. `*/path.zsh` -- all topics, alphabetical by directory name
3. `*/*.zsh` (excluding path.zsh and completion.zsh) -- alphabetical by directory, then filename
4. `*/completion.zsh` -- loaded after `compinit`
```

(No change to the list itself — but add a note after the list:)

After the "Alphabetical ordering is load-bearing" paragraph, add:

```markdown
**Platform helpers** (`is_macos`, `is_linux`) are defined in `system/platform.zsh` and available during the `*.zsh` pass (step 3). They are NOT available during the `path.zsh` pass (step 2) — use inline `[[ "$(uname -s)" == "Darwin" ]]` guards in path files.
```

- [ ] **Step 2: Update File Conventions section**

Add these entries to the File Conventions list:

```markdown
- `*.sh` -- not auto-sourced (the `.sh` extension prevents it). Used for `install.sh` scripts and other executable scripts within topic directories.
- `npm-globals.txt` -- declarative package lists, one package per line. Read by `install.sh` in the same topic directory.
```

- [ ] **Step 3: Add Cross-Platform section**

Add a new section after "Gotchas":

```markdown
## Cross-Platform

Shell config loads on both macOS and Linux. Packages (Homebrew) are macOS-only.

- `path.zsh` files guard on `[[ "$(uname -s)" == "Darwin" ]]` (inline, since platform helpers load later)
- Other `.zsh` files use `is_macos` / `is_linux` helpers from `system/platform.zsh`
- `install.sh` scripts run on all platforms. Self-guard with `[ "$(uname -s)" = "Darwin" ] || exit 0` if macOS-only.
- Bootstrap Phase 4 (Homebrew) is macOS-only. Phase 5 (install scripts) runs everywhere.
```

- [ ] **Step 4: Add XDG Policy section**

Add after Cross-Platform:

```markdown
## XDG Base Directories

`system/env.zsh` exports `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` with spec-compliant defaults. Existing values are preserved.

- **New configs** use `$XDG_CONFIG_HOME/<tool>/` via `install.sh` symlinks (see `ghostty/install.sh`, `starship/install.sh`).
- **Legacy configs** (git, vim, zshrc) stay in `$HOME` — company tooling co-owns `.gitconfig` and `.zshrc`.
- **Starship** lives at `$XDG_CONFIG_HOME/starship.toml` (its native default location).
```

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "Update AGENTS.md with cross-platform, XDG, and package list docs"
```

---

### Task 10: Documentation Updates — .claude/rules/

**Files:**
- Modify: `.claude/rules/shell-scripts.md`
- Modify: `.claude/rules/symlink.md`
- Create: `.claude/rules/macos.md`
- Create: `.claude/rules/xdg.md`

- [ ] **Step 1: Update `.claude/rules/shell-scripts.md`**

Add to the end of the file:

```markdown
- Platform detection: `is_macos` and `is_linux` helpers (from `system/platform.zsh`) are available in `*.zsh` files. In `path.zsh` files, use inline `[[ "$(uname -s)" == "Darwin" ]]` guards instead (path files load before the helpers).
- `*.sh` files in topic directories are not auto-sourced. Used for `install.sh` and standalone scripts like `macos/defaults.sh`.
```

- [ ] **Step 2: Update `.claude/rules/symlink.md`**

Add to the end of the file:

```markdown
- For new tool configs, prefer XDG-based symlinks via `install.sh` (targeting `$XDG_CONFIG_HOME/<tool>/`) over `*.symlink` files. See `starship/install.sh` and `ghostty/install.sh` for examples.
```

- [ ] **Step 3: Create `.claude/rules/macos.md`**

```markdown
- `macos/defaults.sh` contains `defaults write` commands for macOS preferences. Named `.sh` to prevent auto-sourcing.
- `macos/install.sh` runs `defaults.sh` during bootstrap.
- Run `sh macos/defaults.sh` manually after macOS updates (updates can reset preferences).
- Add new defaults to `macos/defaults.sh` with a comment explaining what each setting does and its default value.
```

- [ ] **Step 4: Create `.claude/rules/xdg.md`**

```markdown
- XDG base directories are exported in `system/env.zsh`. They use `:-` to preserve existing values.
- New tool configs should target `$XDG_CONFIG_HOME/<tool>/` via `install.sh` symlinks, not `*.symlink` to `$HOME`.
- Git, vim, and zshrc stay in `$HOME` — company tooling co-owns `.gitconfig` and `.zshrc`.
- Starship config lives at `$XDG_CONFIG_HOME/starship.toml`.
```

- [ ] **Step 5: Commit**

```bash
git add .claude/rules/shell-scripts.md .claude/rules/symlink.md .claude/rules/macos.md .claude/rules/xdg.md
git commit -m "Update and add Claude rules for platform, XDG, and macOS conventions"
```

---

### Task 11: Verification

- [ ] **Step 1: Full syntax check on all new and modified .zsh files**

```bash
zsh -n system/platform.zsh && \
zsh -n system/env.zsh && \
zsh -n homebrew/path.zsh && \
zsh -n node/path.zsh && \
zsh -n pg/path.zsh && \
zsh -n system/grc.zsh && \
zsh -n zsh/prompt.zsh && \
zsh -n zsh/zshrc.symlink && \
echo "All .zsh files OK"
```

Expected: `All .zsh files OK`

- [ ] **Step 2: Shellcheck on all new .sh files**

```bash
shellcheck node/install.sh macos/defaults.sh macos/install.sh starship/install.sh
```

Expected: no errors

- [ ] **Step 3: Bootstrap syntax check**

```bash
bash -n script/bootstrap && echo "OK"
```

Expected: `OK`

- [ ] **Step 4: Test shell loads without errors**

```bash
zsh -c 'source zsh/zshrc.symlink && echo "Shell loaded OK"'
```

Expected: `Shell loaded OK` (may see warnings if Homebrew/tools not in this environment, but no errors)

- [ ] **Step 5: Run `reload!` to verify live shell**

Run: `reload!`
Expected: shell reloads without errors, prompt appears normally
