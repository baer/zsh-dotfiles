---
name: add-env
description: Add an environment variable to the correct topic's env.zsh file
disable-model-invocation: true
argument-hint: [VAR_NAME=value]
allowed-tools: Read Edit Write Bash(zsh -n *) Glob
---

Add environment variable `$ARGUMENTS` to the appropriate `env.zsh` file.

1. Determine the relevant topic directory (e.g., EDITOR goes in `editors/`, PG* goes in `pg/`).
2. If the topic has an `env.zsh`, add the export there. If not, create `env.zsh` in the topic directory.
3. If no topic matches, create or edit `system/env.zsh`.
4. Use the pattern: `export VAR_NAME='value'` (single quotes unless the value needs expansion).
5. Run `zsh -n` on the edited file.
6. Remind the user: secrets belong in `~/.localrc`, not in tracked files.
