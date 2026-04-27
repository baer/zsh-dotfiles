# zsh-dotfiles

Personal zsh dotfiles using topical organization

## Architecture

`zsh/zshrc.symlink` sources all `*.zsh` files in this order:

1. `~/.localrc` (if exists) -- secrets and machine-specific config
2. `*/path.zsh` -- all topics, alphabetical by directory name
3. `*/*.zsh` (excluding path.zsh and completion.zsh) -- alphabetical by directory, then filename
4. `*/completion.zsh` -- loaded after `compinit`

**Alphabetical ordering is load-bearing.** Topics load by directory name, so later directories win if two topics set the same variable.

**Platform helpers** (`is_macos`, `is_linux`) are defined in `system/_platform.zsh` and available during the `*.zsh` pass (step 3). They are NOT available during the `path.zsh` pass (step 2) — use inline `[[ "$(uname -s)" == "Darwin" ]]` guards in path files.

## Commands

- `script/bootstrap` -- idempotent setup and maintenance (symlinks, git config, brew update/upgrade/bundle, topic install scripts)
- `script/localrc` -- audits and manages repo-owned `~/.localrc` overrides in a reserved block
- `script/brew-skip-detect` -- detects casks installed outside Homebrew, offers skip or adopt per-app, writes skip list to `~/.localrc`
- `script/brew-update` -- standalone Homebrew maintenance: update, upgrade, bundle, drift check, vuln check. Flags: `--verbose`, `--skip-upgrade`, `--skip-checks`. Alias: `brewup`
- `script/brew-audit` -- detects Brewfile drift (installed packages not in Brewfile) and offers to adopt manually installed apps into Homebrew management. Actions: `skip` (this run), `add` (to Brewfile), `remove` (uninstall), `skip-local` (ignore on this machine only), `skip-always` (ignore on all machines)
- `reload!` -- re-source ~/.zshrc
- `source ~/.zshrc` -- same as reload!, works outside zsh

## File Conventions

- `*.zsh` -- auto-sourced into shell environment. Not executed directly; no shebang needed.
- `*.symlink` -- live-symlinked to `$HOME/.{name}` (stripping `.symlink`). **Edits take effect immediately.**
- `path.zsh` -- loaded first (PATH setup)
- `completion.zsh` -- loaded last (after compinit)
- `install.sh` -- executed by `script/bootstrap`. Extension is `.sh` to avoid auto-sourcing.
- `*.sh` -- not auto-sourced (the `.sh` extension prevents it). Used for `install.sh` scripts and other executable scripts within topic directories.
- `npm-globals.txt` -- declarative package lists, one package per line. Read by `install.sh` in the same topic directory.
- `bin/*` -- added to $PATH. Must have a shebang and be executable.

## Verification

Automated (PostToolUse hooks run on every Edit/Write):
- `.zsh` files: `zsh -n` syntax check -- blocks save on failure
- `bin/*` scripts: `shellcheck` -- blocks save on failure
- `Brewfile`: alphabetical ordering check -- blocks save on failure

Manual (run after completing changes):
- `reload!` or `source ~/.zshrc` -- verify shell changes load without errors
- `brew bundle` -- verify Brewfile installs correctly
- `bats script/test/lib/` -- run the BATS test suite for script library functions

## Work Machines

The Brewfile is the canonical list of all desired packages. On work machines where company MDM/Chef manages some apps, `HOMEBREW_BUNDLE_CASK_SKIP` tells `brew bundle` which casks to skip.

- `script/brew-skip-detect` auto-detects casks already installed outside Homebrew and offers per-app skip or adopt
- `script/bootstrap` runs detection automatically before installing dependencies, and shows a drift nudge after brew bundle
- Re-run `script/brew-skip-detect` if managed apps change
- Run `script/brew-audit` periodically to find packages installed via `brew install` but missing from the Brewfile

## Gotchas

- **Symlinks are live**: Editing `*.symlink` files changes your active dotfiles immediately (they're symlinked, not copied).
- **Interactive rebase**: Use `git ri` for interactive rebase (`ri = rebase -i`). Plain `git rebase` is non-interactive.
- **Private config**: `~/.localrc` is sourced early but git-ignored. Use `script/localrc` for repo-managed overrides; keep secrets and one-off machine env vars outside the managed block.
- **`brew bundle --cleanup` is banned**: It triggers Homebrew's autoremove, which can delete packages that ARE in the Brewfile if they were originally installed as dependencies (Homebrew/brew#21350). Use `script/brew-audit` for drift resolution instead. If a converge mode is ever needed, prefix with `HOMEBREW_NO_INSTALL_CLEANUP=1` and test thoroughly.
- **fsmonitor + Homebrew**: `core.fsmonitor=true` is enabled globally for performance, but disabled in Homebrew tap repos via `includeIf` + `git/gitconfig-homebrew.symlink`. Without this override, fsmonitor daemons inherit Homebrew's update lock FD and permanently block `brew update`. If you see `lockf: already locked` errors, check: `lsof "$(brew --prefix)/var/homebrew/locks/update"`.

## Cross-Platform

Shell config loads on both macOS and Linux. Packages (Homebrew) are macOS-only.

- `path.zsh` files guard on `[[ "$(uname -s)" == "Darwin" ]]` (inline, since platform helpers load later)
- Other `.zsh` files use `is_macos` / `is_linux` helpers from `system/_platform.zsh`
- `install.sh` scripts run on all platforms. Self-guard with `[ "$(uname -s)" = "Darwin" ] || exit 0` if macOS-only.
- Bootstrap Phase 4 (Homebrew) is macOS-only. Phase 5 (install scripts) runs everywhere.

## XDG Base Directories

`system/env.zsh` exports `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME` with spec-compliant defaults. Existing values are preserved.

- **New configs** use `$XDG_CONFIG_HOME/<tool>/` via `install.sh` symlinks (see `ghostty/install.sh`, `starship/install.sh`).
- **Legacy configs** (git, zshrc) stay in `$HOME` — company tooling co-owns `.gitconfig` and `.zshrc`.
- **Starship** lives at `$XDG_CONFIG_HOME/starship.toml` (its native default location).
