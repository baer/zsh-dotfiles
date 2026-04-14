---
name: add-path
description: Add a PATH entry to the correct topic's path.zsh file
disable-model-invocation: true
argument-hint: [path-entry e.g. "/usr/local/go/bin"]
allowed-tools: Read Edit Write Bash(zsh -n *) Glob
---

Add `$ARGUMENTS` to PATH.

1. Determine which topic the path belongs to. Check if a relevant topic directory exists (e.g., `go/` for go paths, `node/` for node paths).
2. If the topic has a `path.zsh`, add the entry there. If not, create `path.zsh` in the topic directory.
3. If no topic matches, add to `system/_path.zsh`.
4. Use the pattern: `export PATH="/new/path:$PATH"` -- prepend, not append.
5. Run `zsh -n` on the edited file.
6. Tell the user to run `reload!` to activate.
