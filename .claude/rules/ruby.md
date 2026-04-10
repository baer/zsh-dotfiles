---
globs: ["ruby/*"]
---

- rbenv is initialized in `ruby/rbenv.zsh` (conditional on rbenv being installed). Ruby version management goes through rbenv.
- `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES` is set here to work around a Ruby/macOS fork safety bug.
