# Baerly dotfiles

Topical zsh dotfiles with modern CLI tooling, Homebrew automation, and smart handling of work machines.

## Install

```sh
git clone https://github.com/baer/zsh-dotfiles.git
cd ~/zsh-dotfiles
script/bootstrap
```

Bootstrap will:

1. Prompt for your Git author name and email (stored in `git/gitconfig.local.symlink`, which is git-ignored)
2. Symlink all `*.symlink` files to `$HOME` (e.g., `zsh/zshrc.symlink` becomes `~/.zshrc`)
3. On macOS, detect company-managed apps and set up Homebrew cask filtering (see [Work Machines](#work-machines))
4. Install all Homebrew packages and casks from the `Brewfile` via `brew bundle`

## Topical Organization

Everything is organized into topic directories. Add a new `java/` directory and any `*.zsh` files inside are automatically sourced into your shell.

### Current Topics

`atuin` `bin` `claude` `functions` `ghostty` `git` `homebrew` `node` `pg` `starship` `system` `vim` `zsh`

### Infrastructure (not topics)

| Directory | Purpose |
|-----------|---------|
| `script/` | Bootstrap, Homebrew maintenance tools, shared libraries, and tests |
| `docs/` | Development plans and specs |

### File Conventions

| Pattern | Behavior |
|---------|----------|
| `topic/*.zsh` | Auto-sourced into shell (alphabetically by topic, then filename) |
| `topic/path.zsh` | Loaded **first** across all topics (PATH setup) |
| `topic/completion.zsh` | Loaded **last**, after `compinit` |
| `topic/install.sh` | Run by `script/bootstrap` (`.sh` extension prevents auto-sourcing) |
| `topic/*.symlink` | Symlinked to `$HOME/.{name}` by `script/bootstrap` — edits are live |
| `bin/*` | Added to `$PATH`, available everywhere |

## What's Included

### Shell Tooling

The `Brewfile` installs and the shell config wires up a set of modern CLI replacements:

| Tool | Replaces | Notes |
|------|----------|-------|
| [eza](https://github.com/eza-community/eza) | `ls` | Aliased to `ls`, `ll`, `tree` |
| [bat](https://github.com/sharkdp/bat) | `cat` | Aliased to `cat`; also used as `MANPAGER` |
| [fd](https://github.com/sharkdp/fd) | `find` | Backend for fzf file/directory search |
| [ripgrep](https://github.com/BurntSushi/ripgrep) | `grep` | Fast regex search |
| [delta](https://github.com/dandavella/delta) | `diff` | Git pager with line numbers and syntax highlighting |
| [fzf](https://github.com/junegunn/fzf) | — | Ctrl+T (files), Alt+C (dirs) |
| [atuin](https://github.com/atuinsh/atuin) | shell history | Synced, searchable history; takes over Ctrl+R from fzf |
| [zoxide](https://github.com/ajeetdsouza/zoxide) | `cd` | Frecency-based directory jumping via `z` |
| [starship](https://starship.rs) | prompt | Cross-shell prompt with random emoji per command |
| [mise](https://mise.jdx.dev) | nvm/rbenv/asdf | Polyglot runtime version manager |
| [btop](https://github.com/aristocratos/btop) | `top` | Resource monitor |
| [grc](https://github.com/garabik/grc) | — | Colorizes standard Unix tool output |

### Shell Aliases

Defined in `zsh/aliases.zsh`:

- `..`, `...` — Quick navigation
- `reload!` — Re-source `~/.zshrc`
- `path` — Pretty-print `$PATH` (one entry per line)
- `ip` — Show public IP address
- `pubkey` — Copy SSH public key to clipboard
- `rm`, `cp`, `mv` — Wrapped with `-i` for confirmation prompts
- `ls`, `ll`, `tree` — eza-powered (falls back to GNU ls)
- `cat` — bat-powered with syntax highlighting

### Git Extras

Git config lives in `git/gitconfig.symlink` with delta as the diff pager and 20+ aliases. Notable commands:

- `git up` — Update default branch from origin and return to current branch (pass `-r` to rebase)
- `git nuke <branch>` — Delete a branch locally and on origin
- `git credit "Name" email` — Amend last commit with a different author
- `git edit-new` — Open all new/modified files in `$EDITOR`
- `git undo` — Soft-reset the last commit
- `git cb` — Copy current branch name to clipboard

### Utility Scripts in `bin/`

- `dot` — Update everything: brew update/upgrade, install Brewfile packages, run topic install scripts
- `dot -e` — Open the dotfiles directory in your editor
- `e [path]` — Open a file or directory in `$EDITOR` (defaults to current dir)
- `ee` — Open `$EDITOR` with `--wait` for interactive use
- `a [-- agent-args...]` — Launch `$AGENT` (defaults to `claude`)
- `a -d [-- agent-args...]` — Launch `$AGENT` with the harness-specific dangerous-mode flag

## Day-to-Day

```sh
dot           # Update Homebrew packages, run install scripts
dot -e        # Edit dotfiles
reload!       # Re-source ~/.zshrc after changes
```

## Work Machines

On company machines where MDM or Chef manages apps (1Password, Chrome, Zoom, etc.), `script/bootstrap` automatically detects these by checking `/Applications` and system package receipts (`pkgutil`). It writes a `HOMEBREW_BUNDLE_CASK_SKIP` variable to `~/.localrc` so `brew bundle` skips those casks.

The Brewfile itself reads this skip list from `~/.localrc` at install time, so casks managed by your company are never touched by Homebrew.

If managed apps change later, re-run:

```sh
script/brew-skip-detect
```

Running `dot` on a work machine without the skip list configured will print a reminder.

## `~/.localrc`

Machine-specific config that shouldn't be committed goes in `~/.localrc` (git-ignored). It's sourced first in the zsh loading order — use it for secrets, API keys, and the Homebrew cask skip list.

## For AI Agents

See [AGENTS.md](AGENTS.md) for architecture, commands, file conventions, and gotchas.
