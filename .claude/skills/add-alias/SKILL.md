---
name: add-alias
description: Add a shell alias to zsh/aliases.zsh in the correct section
disable-model-invocation: true
argument-hint: [alias-definition e.g. "ll='ls -la'"]
allowed-tools: Read Edit Bash(zsh -n *)
---

Add the alias `$ARGUMENTS` to `zsh/aliases.zsh`.

1. Read `zsh/aliases.zsh` and identify the existing sections (Navigation, Shortcuts, Safeguards, ls/colors).
2. Determine which section the new alias belongs in. If none fit, add it before the Safeguards section.
3. Add the alias line: `alias name='command'`.
4. Run `zsh -n zsh/aliases.zsh` to verify syntax.
5. Tell the user to run `reload!` to activate.
