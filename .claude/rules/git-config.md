---
globs: ["git/*"]
---

- `git/gitconfig.symlink` is the shared git config. `git/gitconfig.local.symlink` holds private credentials and is git-ignored.
- `rebase` is no longer aliased to `rebase -i`. Use `git ri` for interactive rebase. Scripts can safely call `git rebase` directly.
- `git/gitignore.symlink` is the global gitignore (via `core.excludesfile`).
