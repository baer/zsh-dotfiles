# zsh-dotfiles

Personal zsh dotfiles using topical organization (fork of holman/dotfiles).

## Architecture

`zsh/zshrc.symlink` sources all `*.zsh` files in this order:

1. `~/.localrc` (if exists) -- secrets and machine-specific config
2. `*/path.zsh` -- all topics, alphabetical by directory name
3. `*/*.zsh` (excluding path.zsh and completion.zsh) -- alphabetical by directory, then filename
4. `*/completion.zsh` -- loaded after `compinit`

**Alphabetical ordering is load-bearing.** Topics load by directory name, so `system/` always loads after `editors/`. This means `system/env.zsh` (EDITOR='code') intentionally overrides `editors/env.zsh` (EDITOR='zed'). The final EDITOR value 'code' is correct.

## Commands

- `script/bootstrap` -- initial setup (creates symlinks to $HOME, configures git, runs dot)
- `bin/dot` -- ongoing maintenance (brew update/upgrade, runs topic install scripts)
- `brew bundle` -- install Brewfile packages
- `reload!` -- re-source ~/.zshrc
- `source ~/.zshrc` -- same as reload!, works outside zsh

## File Conventions

- `*.zsh` -- auto-sourced into shell environment. Not executed directly; no shebang needed.
- `*.symlink` -- live-symlinked to `$HOME/.{name}` (stripping `.symlink`). **Edits take effect immediately.**
- `path.zsh` -- loaded first (PATH setup)
- `completion.zsh` -- loaded last (after compinit)
- `install.sh` -- executed by `script/install`. Extension is `.sh` to avoid auto-sourcing.
- `bin/*` -- added to $PATH. Must have a shebang and be executable.

## Verification

- `reload!` or `source ~/.zshrc` -- verify shell changes load without errors
- `zsh -n <file>` -- syntax-check a .zsh file without executing it
- `brew bundle --no-lock` -- verify Brewfile syntax

## Gotchas

- **Symlinks are live**: Editing `*.symlink` files changes your active dotfiles immediately (they're symlinked, not copied).
- **git rebase is interactive**: `git/gitconfig.symlink` aliases `rebase = rebase -i`. Never call `git rebase` expecting non-interactive behavior.
- **Private config**: `~/.localrc` is sourced early but git-ignored. Use it for secrets and machine-specific env vars.
- **No tests or linters**: Verify changes with `reload!` or `zsh -n`.
