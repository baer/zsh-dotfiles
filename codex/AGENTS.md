# Personal Codex Instructions

## Git Commits

When committing, inspect the actual staged diff first:
`git status --short && git diff --cached --stat && git diff --cached`.
If nothing is staged, inspect the unstaged diff instead.

Write atomic commits when possible. If unrelated changes are mixed, propose a split.

Use Conventional Commits unless you have instructions to use a different style:

`type(scope): imperative summary`

Use a specific subject, not "update/fix changes". For non-trivial changes,
add a wrapped body explaining what changed and why. Mention tests only if
actually run. Never add AI attribution unless requested.
