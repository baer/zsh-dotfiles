# baer does dotfiles

A fork of Zach Holman's excellent [dotfiles project](https://github.com/holman/dotfiles), customized for my setup.

## Install

```sh
git clone https://github.com/baer/zsh-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
script/bootstrap
```

Bootstrap handles everything: symlinks `*.symlink` files to `$HOME`, configures git, detects company-managed apps, and installs Homebrew packages.

## Topical Organization

Everything's built around topic areas. Each directory is a "topic" — add a `java` directory and any `*.zsh` files inside get auto-sourced into your shell. Any `*.symlink` files get symlinked to `$HOME` when you run `script/bootstrap`.

### Current Topics

`atuin` `bin` `editors` `functions` `git` `homebrew` `macos` `node` `pg` `ruby` `starship` `system` `vim` `zsh`

### Special Files

- **bin/** — Added to `$PATH`, available everywhere
- **topic/\*.zsh** — Auto-sourced into shell environment
- **topic/path.zsh** — Loaded first (PATH setup)
- **topic/completion.zsh** — Loaded last (after compinit)
- **topic/install.sh** — Run by `script/install` (`.sh` extension avoids auto-sourcing)
- **topic/\*.symlink** — Symlinked to `$HOME/.{name}` by `script/bootstrap`

## Day-to-Day

- `dot` — Update environment (brew update/upgrade, install Brewfile packages, run install scripts)
- `reload!` — Re-source ~/.zshrc
- `dot -e` — Open dotfiles directory in your editor

## Work Machines

On company machines where MDM or Chef manages apps like 1Password, Chrome, or Zoom, `script/bootstrap` automatically detects these and skips them during Homebrew installs. It checks `/Applications` and system package receipts, then stores the skip list in `~/.localrc`.

If managed apps change later, re-run: `script/brew-skip-detect`

## For AI Agents

See [AGENTS.md](AGENTS.md) for architecture, commands, file conventions, and gotchas.
