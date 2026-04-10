---
name: add-brew-package
description: Add a Homebrew package to Brewfile maintaining section order and alphabetical sorting
disable-model-invocation: true
argument-hint: [package-name]
allowed-tools: Bash(brew *) Read Edit Grep
---

Add the package `$ARGUMENTS` to the Brewfile.

1. Determine if the package is a `tap`, `brew` (CLI tool), or `cask` (GUI app).
   - If unclear, run `brew info $ARGUMENTS` to check. Casks show "cask" in the output.
2. Read the current Brewfile.
3. Add the entry to the correct section (taps first, then brews, then casks), in alphabetical order within that section.
4. Run `brew bundle --no-lock` to verify Brewfile syntax.
5. Tell the user to run `brew bundle` to install.
