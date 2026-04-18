# Dotfiles Improvements Design

Four improvements to the zsh-dotfiles project: cross-platform support, multi-package-manager lists, XDG base directory compliance, and macOS defaults.

## 1. Cross-Platform Support (Graceful Degradation)

### Goal

Shell environment loads cleanly on Linux (aliases, git config, prompt, functions). Packages remain macOS-only. No errors from missing Homebrew paths on Linux.

### Design

**New file: `system/platform.zsh`**

Defines `is_macos` and `is_linux` helper functions using `uname -s`. Available to all subsequently-loaded files.

```zsh
is_macos() { [[ "$(uname -s)" == "Darwin" ]]; }
is_linux() { [[ "$(uname -s)" == "Linux" ]]; }
```

**Files requiring platform guards:**

| File | Guard needed |
|------|-------------|
| `homebrew/path.zsh` | Inline `[[ "$(uname -s)" == "Darwin" ]] \|\| return 0` (loads in path.zsh pass, before `is_macos` helper is available) |
| `node/path.zsh` | Inline uname guard (same reason — path.zsh pass) |
| `pg/path.zsh` | Inline uname guard (same reason — path.zsh pass) |
| `system/grc.zsh` | `is_macos \|\| return 0` (loads in *.zsh pass, helper is available) |
| `zshrc.symlink` lines 56-61 | Guard Homebrew plugin sourcing on `[[ -n "$HOMEBREW_PREFIX" ]]` |

**Load order constraint:** `path.zsh` files load before `*.zsh` files (step 2 vs step 3 in zshrc). The `is_macos`/`is_linux` helpers from `system/platform.zsh` are not available during the path.zsh pass. Path files must use inline `uname` checks. All other `.zsh` files can use the helpers.

Files already safe (use `$+commands` checks): `zsh/tools.zsh`, `zsh/prompt.zsh`, `node/mise_and_npm.zsh`.

**Bootstrap changes:**

Topic `install.sh` scripts are currently run inside the macOS-only block (Phase 4). Separate them so platform-agnostic install scripts (e.g., `claude/install.sh`, `node/install.sh`) run on all platforms. Each install script self-guards if it needs macOS.

## 2. Multi-Package-Manager Lists

### Goal

Declare global npm packages in a text file. Install them during bootstrap. Extensible pattern for pip/cargo if needed later.

### Design

**New file: `node/npm-globals.txt`**

```
yarn
pnpm
```

One package per line. Comments with `#`. Blank lines ignored.

**New file: `node/install.sh`**

Reads `npm-globals.txt`, skips packages already installed globally, runs `npm install -g` for missing ones. Exits cleanly if `npm` is not available.

**Bootstrap integration:** Automatically discovered by the existing `find "$DOTFILES_ROOT" -name install.sh` loop. No bootstrap changes needed beyond the cross-platform separation from Section 1.

**Future extensibility:** Same pattern for other ecosystems: `python/pip-globals.txt` + `python/install.sh`, `rust/cargo-globals.txt` + `rust/install.sh`. Zero framework needed.

## 3. XDG Base Directory Compliance

### Goal

Set XDG env vars so all XDG-aware tools benefit. Move starship config from `~/.starship` to `~/.config/starship.toml`. Leave git, vim, and zshrc in `$HOME` (company constraints for git/zshrc, low value for vim). Establish policy: new configs use XDG going forward.

### Design

**New file: `system/env.zsh`**

```zsh
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
```

Uses `:-` so existing values (from company tooling, Linux distro) are preserved.

**Starship migration:**

1. Rename `starship/starship.symlink` to `starship/config`
2. Create `starship/install.sh` that symlinks to `$HOME/.config/starship.toml`
3. Update `zsh/prompt.zsh`: `export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"`
4. Migration: if `~/.starship` exists as an old symlink, `starship/install.sh` removes it

**What stays in `$HOME` and why:**

| File | Reason |
|------|--------|
| `.zshrc` | Company `setup.sh` appends `source ~/.gusto/init.sh` to it |
| `.gitconfig` | Company `setup.sh` runs `git config --global` which writes to it |
| `.gitignore`, `.gitattributes` | Co-located with gitconfig for consistency |
| `.gitconfig.local` | Included from `.gitconfig` |
| `.vimrc` | Low value (EDITOR is VS Code) |

**XDG policy for new configs:** Use `$XDG_CONFIG_HOME/<tool>/` via `install.sh` symlinks, not `*.symlink` to `$HOME`. Ghostty and Claude already follow this pattern. Document in AGENTS.md.

## 4. macOS Defaults

### Goal

Set fast keyboard repeat rate on macOS. Provide a reusable pattern for future defaults.

### Design

**New topic directory: `macos/`**

**New file: `macos/defaults.sh`**

Named `.sh` (not `.zsh`) to prevent auto-sourcing on every shell startup. Contains:

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

**New file: `macos/install.sh`**

Runs `macos/defaults.sh` during bootstrap. Self-guards on macOS.

```sh
#!/bin/sh
if [ "$(uname -s)" = "Darwin" ]; then
  dir="$(cd "$(dirname "$0")" && pwd)"
  sh "$dir/defaults.sh"
fi
```

## Documentation Updates

### AGENTS.md

- Add `system/platform.zsh` (platform detection helpers `is_macos`, `is_linux`)
- Add `macos/` topic directory
- Add XDG policy: new configs use `$XDG_CONFIG_HOME/<tool>/` via `install.sh`, not `*.symlink`
- Note `install.sh` scripts run on all platforms unless they self-guard
- Document `npm-globals.txt` package list pattern

### .claude/rules/

- `shell-scripts.md`: mention `is_macos`/`is_linux` platform helpers
- `symlink.md`: note XDG-based configs use `install.sh` instead of `*.symlink`
- New `macos.md`: macOS defaults convention
- New `xdg.md`: XDG base directory policy

## Scope Summary

**New files (10):**
- `system/platform.zsh`
- `system/env.zsh`
- `node/npm-globals.txt`
- `node/install.sh`
- `starship/install.sh`
- `macos/defaults.sh`
- `macos/install.sh`
- `.claude/rules/macos.md`
- `.claude/rules/xdg.md`

**Renamed files (1):**
- `starship/starship.symlink` -> `starship/config`

**Modified files (9):**
- `homebrew/path.zsh` (add platform guard)
- `node/path.zsh` (add platform guard)
- `pg/path.zsh` (add platform guard)
- `system/grc.zsh` (add platform guard)
- `zsh/zshrc.symlink` (guard Homebrew plugin sourcing)
- `zsh/prompt.zsh` (update STARSHIP_CONFIG path)
- `script/bootstrap` (separate install scripts from macOS-only block)
- `AGENTS.md` (architecture updates)
- `.claude/rules/shell-scripts.md` (platform helpers)
- `.claude/rules/symlink.md` (XDG note)
