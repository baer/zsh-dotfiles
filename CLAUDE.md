# Claude-Specific Context

See AGENTS.md for architecture, commands, file conventions, and gotchas.

## Hooks

- **Symlink warning**: A PostToolUse hook warns when you edit `*.symlink` files, since they're live-symlinked to $HOME.
- **Rebase block**: A PreToolUse hook blocks `git rebase` commands (aliased to interactive mode in this repo).
- **zsh syntax check**: A PostToolUse hook runs `zsh -n` on edited `.zsh` files and blocks on syntax errors.
- **shellcheck**: A PostToolUse hook runs `shellcheck` on edited `bin/*` scripts and blocks on errors.
- **Brewfile ordering**: A PostToolUse hook validates alphabetical ordering within Brewfile sections and blocks on violations.

## Skills

- `/add-brew-package [name]` -- add a package to the Brewfile with correct section and alphabetical ordering
- `/new-topic [name]` -- scaffold a new topic directory with standard file conventions
- `/add-alias [definition]` -- add a shell alias to `zsh/aliases.zsh` in the correct section
- `/add-path [path]` -- add a PATH entry to the correct topic's `path.zsh`
- `/add-env [VAR=value]` -- add an environment variable to the correct topic's `env.zsh`
