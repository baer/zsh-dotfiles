# Brief: Add mas-cli for Mac App Store tracking

## The idea

[mas-cli](https://github.com/mas-cli/mas) is a command-line interface for the Mac App Store. It integrates directly with Homebrew's Brewfile format — you add `mas` entries alongside your existing `brew` and `cask` entries, and `brew bundle` installs them.

This is the lowest-friction addition identified in the landscape research. No new tools, no new workflows — just new lines in the existing Brewfile.

## What to explore

1. **Add mas to the Brewfile:**
   ```ruby
   brew 'mas'
   ```
   Then identify App Store apps to track. Run `mas list` to see what's currently installed with their IDs.

2. **Add mas entries to the Brewfile.** The format is:
   ```ruby
   mas 'Xcode', id: 497799835
   mas '1Password', id: 1333542190
   ```
   These go in a new section after casks, following the repo's convention of alphabetical ordering within sections and blank lines between sections.

3. **Important limitation (macOS 12+):** `mas install` only works for apps you've previously purchased/downloaded from the App Store. It cannot trigger a first-time purchase. `mas purchase` was removed due to Apple API changes. So this is for tracking and re-installing known apps, not discovering new ones.

4. **Integration with brew-audit:** The drift detection in `script/brew-audit` currently checks taps, formulae, and casks. It would need a new category for mas apps. Check whether `brew bundle check` already covers mas entries (it should — mas is a supported Brewfile directive). The Phase 5 drift warning in bootstrap would also need updating if you want to count mas drift.

5. **Integration with brew-skip-detect:** Some App Store apps might also exist as casks (e.g., 1Password). Decide which source to prefer per-app. The skip-detect script currently only handles casks.

## Design considerations

- The Brewfile section ordering would become: taps, brews, casks, mas (update `.claude/rules/brewfile.md`)
- The Brewfile PostToolUse hook that validates alphabetical ordering needs to know about `mas` entries
- `mas upgrade` can be added to any maintenance/update flow alongside `brew upgrade`
- On fresh machines, you'll need to sign into the App Store first — bootstrap should handle or document this
- Consider whether `mas` entries should be conditional (some apps are personal-only, some are work-only). The same `HOMEBREW_BUNDLE_MAS_SKIP` env var exists for this purpose.

## Key files

- `Brewfile` — add `brew 'mas'` and `mas` entries
- `.claude/rules/brewfile.md` — update section ordering docs
- `script/brew-audit` — may need mas drift detection
- `script/bootstrap` — App Store sign-in prerequisite
