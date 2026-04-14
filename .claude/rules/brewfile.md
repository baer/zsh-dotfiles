---
globs: ["Brewfile"]
---

- Brewfile is organized: taps, then brews, then casks. Keep entries alphabetical within each section.
- After editing, run `brew bundle` to install new entries.
- `Brewfile.lock.json` is git-ignored.
- Example of correct ordering:
  ```
  tap 'homebrew/bundle'
  tap 'homebrew/cask-fonts'

  brew 'ack'
  brew 'git'

  cask '1password'
  cask 'google-chrome'
  ```
  Blank lines separate sections.
