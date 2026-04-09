---
globs: ["git/*"]
---

- `git/gitconfig.symlink` is the shared git config. `git/gitconfig.local.symlink` holds private credentials and is git-ignored.
- `[alias] rebase = rebase -i` makes all rebase commands interactive. Do not add automation that calls `git rebase` expecting non-interactive behavior.
- `git/gitignore.symlink` is the global gitignore (via `core.excludesfile`).
