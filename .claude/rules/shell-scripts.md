---
globs: ["**/*.zsh", "**/*.sh", "bin/*"]
---

- Shell scripts in `bin/` must have a shebang (`#!/bin/sh` or `#!/usr/bin/env bash`) and be executable (`chmod +x`).
- `.zsh` files are sourced by zshrc, not executed directly. No shebang needed.
- `*.symlink` files are live-symlinked to `$HOME` — edits take effect immediately.
- New topic directory pattern: `path.zsh` for PATH, `env.zsh` for environment variables, `completion.zsh` for completions (loaded after compinit), `install.sh` for one-time setup.
- PATH entries must prepend: `export PATH="/new/path:$PATH"` (not append). Always double-quote the value.
