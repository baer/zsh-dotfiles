# zsh-dotfiles

Personal zsh dotfiles using topical organization (fork of holman/dotfiles).

## Commands

- `script/bootstrap` — initial setup (symlinks, git config)
- `bin/dot` — update environment (brew update/upgrade)
- `brew bundle` — install Brewfile packages
- `reload!` — re-source ~/.zshrc

## File Conventions

- `*.zsh` — auto-sourced into shell
- `*.symlink` — symlinked to `$HOME/.{name}`
- `path.zsh` loaded first, `completion.zsh` loaded last, `install.sh` run by `script/install`

## Gotchas

- EDITOR override is intentional: topics load alphabetically, so `system/env.zsh` (EDITOR='code') wins over `editors/env.zsh` (EDITOR='zed').
- `git rebase` is aliased to `git rebase -i` (interactive). Don't use in non-interactive automation.
- No tests or linters. Verify with `reload!` or a new shell.
