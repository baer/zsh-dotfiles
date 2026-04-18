---
name: new-topic
description: Scaffold a new topic directory with standard zsh dotfile conventions
disable-model-invocation: true
argument-hint: [topic-name]
allowed-tools: Bash(mkdir *) Write Read
---

Create a new topic directory `$ARGUMENTS/` with the standard file conventions.

Ask the user which files are needed:
- `path.zsh` -- for PATH additions (loaded first, before other .zsh files)
- `env.zsh` -- for environment variables
- `completion.zsh` -- for shell completions (loaded last, after compinit)
- `install.sh` -- for one-time setup (run by `script/bootstrap`, uses .sh extension to avoid auto-sourcing)
- `*.symlink` -- for files that should be symlinked to $HOME

Create the directory and requested files with appropriate boilerplate.

Remind the user: topics load alphabetically by directory name. If this topic's variables should override another topic's, the directory name determines priority (e.g., `system/` loads after `ruby/`).
