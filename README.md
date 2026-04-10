# baer does dotfiles

A fork of Zach Holman's excellent [dotfiles project](https://github.com/holman/dotfiles), customized for my setup.

## Install

```sh
git clone https://github.com/baer/zsh-dotfiles.git ~/.dotfiles
cd ~/.dotfiles
script/bootstrap
brew bundle
```

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

- `bin/dot` — Update environment (brew update/upgrade, run install scripts)
- `brew bundle` — Install Brewfile packages
- `reload!` — Re-source ~/.zshrc

## For AI Agents

See [AGENTS.md](AGENTS.md) for architecture, commands, file conventions, and gotchas.
