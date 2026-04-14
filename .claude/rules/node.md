---
globs: ["node/*"]
---

- Mise is the version manager, activated in `node/mise_and_npm.zsh`. On work machines, `~/.gusto/init.sh` activates mise first; the personal dotfiles skip re-activation via `$_GUSTO_CONFIG_FILES_INITIALIZED`.
- `npm config set save-exact true` is set globally in this file. All npm installs pin exact versions.
- New node-related paths go in `node/path.zsh`, not `system/_path.zsh`.
