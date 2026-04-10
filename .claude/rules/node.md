---
globs: ["node/*"]
---

- NVM is loaded from `$NVM_DIR/nvm.sh` in `node/nvm_and_npm.zsh`. NVM init is slow (~200ms); do not add duplicate loads.
- `npm config set save-exact true` is set globally in this file. All npm installs pin exact versions.
- New node-related paths go in `node/path.zsh`, not `system/_path.zsh`.
