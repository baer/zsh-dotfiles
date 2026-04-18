---
globs: ["**/*.zsh", "**/*.sh", "bin/*"]
---

- Shell scripts in `bin/` must have a shebang (`#!/bin/sh` or `#!/usr/bin/env bash`) and be executable (`chmod +x`).
- `.zsh` files are sourced by zshrc, not executed directly. No shebang needed.
- `*.symlink` files are live-symlinked to `$HOME` — edits take effect immediately.
- New topic directory pattern: `path.zsh` for PATH, `env.zsh` for environment variables, `completion.zsh` for completions (loaded after compinit), `install.sh` for one-time setup.
- PATH entries must prepend: `export PATH="/new/path:$PATH"` (not append). Always double-quote the value.
- Platform detection: `is_macos` and `is_linux` helpers (from `system/platform.zsh`) are available in `*.zsh` files. In `path.zsh` files, use inline `[[ "$(uname -s)" == "Darwin" ]]` guards instead (path files load before the helpers).
- `*.sh` files in topic directories are not auto-sourced. Used for `install.sh` and standalone scripts like `macos/defaults.sh`.
