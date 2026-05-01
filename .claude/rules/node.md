---
globs: ["node/*"]
---

- Mise is the version manager, activated in `node/mise_and_npm.zsh`. Activation runs unconditionally (full `mise activate zsh`) even on work machines where `~/.gusto/init.sh` already ran `mise activate --shims`. Shims-only mode loses to anything prepended to PATH after it (e.g. `homebrew/path.zsh`); full activation installs a chpwd hook that re-prepends mise paths on every prompt, so brew can't shadow mise versions.
- `npm config set save-exact true` is set globally in this file. All npm installs pin exact versions.
- New node-related paths go in `node/path.zsh`, not `system/_path.zsh`.
