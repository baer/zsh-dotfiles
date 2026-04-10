# Claude-Specific Context

See AGENTS.md for architecture, commands, file conventions, and gotchas.

## Hooks

- **Symlink warning**: A PostToolUse hook warns when you edit `*.symlink` files, since they're live-symlinked to $HOME.
- **Rebase block**: A PreToolUse hook blocks `git rebase` commands (aliased to interactive mode in this repo).

## Skills

- `/add-brew-package [name]` -- add a package to the Brewfile with correct section and alphabetical ordering
- `/new-topic [name]` -- scaffold a new topic directory with standard file conventions
