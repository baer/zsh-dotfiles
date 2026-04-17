# zsh-dotfiles

Personal zsh dotfiles using topical organization

## Architecture

`zsh/zshrc.symlink` sources all `*.zsh` files in this order:

1. `~/.localrc` (if exists) -- secrets and machine-specific config
2. `*/path.zsh` -- all topics, alphabetical by directory name
3. `*/*.zsh` (excluding path.zsh and completion.zsh) -- alphabetical by directory, then filename
4. `*/completion.zsh` -- loaded after `compinit`

**Alphabetical ordering is load-bearing.** Topics load by directory name, so `system/` always loads after `editors/`. If two topics set the same variable, the later directory wins.

## Commands

- `script/bootstrap` -- initial setup (creates symlinks to $HOME, configures git, detects company-managed casks, runs dot)
- `script/brew-skip-detect` -- detects casks installed outside Homebrew, writes skip list to `~/.localrc`
- `bin/dot` -- ongoing maintenance (brew update/upgrade, brew bundle, runs topic install scripts)
- `reload!` -- re-source ~/.zshrc
- `source ~/.zshrc` -- same as reload!, works outside zsh

## File Conventions

- `*.zsh` -- auto-sourced into shell environment. Not executed directly; no shebang needed.
- `*.symlink` -- live-symlinked to `$HOME/.{name}` (stripping `.symlink`). **Edits take effect immediately.**
- `path.zsh` -- loaded first (PATH setup)
- `completion.zsh` -- loaded last (after compinit)
- `install.sh` -- executed by `script/bootstrap`. Extension is `.sh` to avoid auto-sourcing.
- `bin/*` -- added to $PATH. Must have a shebang and be executable.

## Verification

Automated (PostToolUse hooks run on every Edit/Write):
- `.zsh` files: `zsh -n` syntax check -- blocks save on failure
- `bin/*` scripts: `shellcheck` -- blocks save on failure
- `Brewfile`: alphabetical ordering check -- blocks save on failure

Manual (run after completing changes):
- `reload!` or `source ~/.zshrc` -- verify shell changes load without errors
- `brew bundle` -- verify Brewfile installs correctly

## Work Machines

The Brewfile is the canonical list of all desired packages. On work machines where company MDM/Chef manages some apps, `HOMEBREW_BUNDLE_CASK_SKIP` tells `brew bundle` which casks to skip.

- `script/brew-skip-detect` auto-detects casks already installed outside Homebrew and writes the skip list to `~/.localrc`
- `script/bootstrap` runs detection automatically before installing dependencies
- `bin/dot` prints a reminder if on a Gusto machine without the skip var set
- Re-run `script/brew-skip-detect` if managed apps change

## Gotchas

- **Symlinks are live**: Editing `*.symlink` files changes your active dotfiles immediately (they're symlinked, not copied).
- **git rebase is interactive**: `git/gitconfig.symlink` aliases `rebase = rebase -i`. Never call `git rebase` expecting non-interactive behavior.
- **Private config**: `~/.localrc` is sourced early but git-ignored. Use it for secrets and machine-specific env vars.
