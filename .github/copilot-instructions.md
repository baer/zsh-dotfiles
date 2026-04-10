# See AGENTS.md for full documentation.

Key safety notes:

- `*.symlink` files are live-symlinked to `$HOME/.{name}`. Edits are immediately active.
- Source order is alphabetical by topic directory. Later directories override earlier ones for same-named vars.
- `git rebase` is aliased to `git rebase -i`. Do not use non-interactively.
- Brewfile: taps, then brews, then casks. Alphabetical within each section.
- Verify: `reload!` or `zsh -n <file>`.
