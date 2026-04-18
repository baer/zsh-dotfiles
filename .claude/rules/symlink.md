---
globs: ["**/*.symlink", "**/*.symlink.example"]
---

- This file is LIVE-SYMLINKED to `$HOME/.{name}` (without the `.symlink` extension). Your edits affect the user's active dotfiles immediately.
- The symlink is created by `script/bootstrap`. Mapping: `topic/foo.symlink` -> `$HOME/.foo`.
- Test shell configs with `reload!` after changes. Non-shell configs (gitconfig, vimrc) are read directly by their applications.
- For new tool configs, prefer XDG-based symlinks via `install.sh` (targeting `$XDG_CONFIG_HOME/<tool>/`) over `*.symlink` files. See `starship/install.sh` and `ghostty/install.sh` for examples.
