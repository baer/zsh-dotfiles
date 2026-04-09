# zsh-dotfiles

Personal zsh dotfiles using topical organization (fork of holman/dotfiles).

## Commands

- `script/bootstrap` — initial setup (symlinks dotfiles, configures git)
- `bin/dot` — update environment (brew update/upgrade, run install scripts)
- `brew bundle` — install Brewfile packages
- `reload!` — re-source ~/.zshrc
- `source ~/.zshrc` — same as reload!, works outside zsh

## File Conventions

- `*.zsh` — auto-sourced into shell environment
- `*.symlink` — symlinked to `$HOME/.{name}` (stripping `.symlink` extension)
- `path.zsh` — loaded first (PATH setup)
- `completion.zsh` — loaded last (after compinit)
- `install.sh` — executed by `script/install`

## Gotchas

- **EDITOR override is intentional**: `editors/env.zsh` sets EDITOR='zed', then `system/env.zsh` overrides to EDITOR='code'. This happens because topics load alphabetically. The final value 'code' is correct.
- **git rebase is interactive**: `git/gitconfig.symlink` aliases `rebase = rebase -i`. Never call `git rebase` expecting non-interactive behavior.
- **Windsurf path bug**: `editors/windsurf.zsh` hardcodes `/Users/holman/` instead of `$HOME`. Known issue.
- **Private config**: `~/.localrc` is sourced early but git-ignored. Use it for secrets and machine-specific env vars.
- **No tests or linters**: Verify changes with `reload!` or open a new shell.
- **Symlinks affect $HOME**: Editing `*.symlink` files changes your active dotfiles immediately (they're symlinked, not copied).
