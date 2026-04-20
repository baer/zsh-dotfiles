---
globs: ["Brewfile"]
---

- Brewfile is organized: taps, then brews, then casks, then mas. Keep entries alphabetical within each section.
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

  mas 'Keynote', id: 409183694
  mas 'Xcode', id: 497799835
  ```
  Blank lines separate sections.
- mas entries use the format: `mas 'App Name', id: <numeric-id>`. Get IDs from `mas search <name>` or `mas list`.
- `mas install` only works for apps previously downloaded from the App Store. It cannot trigger first-time purchases.
- NEVER use `brew bundle --cleanup` or `brew bundle install --cleanup`. It has a known bug (Homebrew/brew#21350) where autoremove deletes Brewfile packages that were originally installed as dependencies. This repo uses `script/brew-audit` for interactive drift resolution instead.
