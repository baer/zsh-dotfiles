# git-up: Target Branch Support

## Summary

Add a positional `BRANCH` argument to `git up` that names a target branch to
rebase onto the freshly-pulled default branch. When given, `--rebase` is
implied. The user ends up on the target branch when the operation completes.

## Motivation

Today `git up --rebase` always rebases the *current* branch. If you're on
`main` and want to update a feature branch, you must first `git checkout
feature-branch`, then `git up --rebase`. The new positional argument lets you
skip the manual checkout:

```
git up feature-branch        # pull main, rebase feature-branch, land on it
```

## CLI Interface

```
Usage: git up [--rebase] [--interactive] [--before CMD] [--after CMD] [BRANCH]
```

### Behavior matrix

| Invocation                  | Pull default | Rebase         | End up on      |
|-----------------------------|-------------|----------------|----------------|
| `git up`                    | Yes         | No             | Current branch |
| `git up --rebase`           | Yes         | Current branch | Current branch |
| `git up feature-x`          | Yes         | feature-x      | feature-x      |
| `git up feature-x -i`       | Yes         | feature-x (interactive) | feature-x |
| `git up feature-x --before "make" --after "yarn"` | Yes | feature-x | feature-x |

### Parsing rules

- The positional arg is the first non-flag argument (does not start with `-`).
- When a target branch is given, `--rebase` is implicitly set to `true`.
- Passing `--rebase` explicitly alongside a target branch is allowed (redundant
  but harmless).
- If the target branch equals the current branch, degrade to existing
  `git up --rebase` behavior (no extra checkout).
- If the target branch equals the default branch, error:
  `"target branch cannot be the default branch"`.
- If the target branch does not exist locally, error:
  `"branch '<name>' does not exist"`.

## Flow

### Standard flow (target branch specified, not already on it)

1. Record `current_branch` (the branch we started on, e.g. `main`).
2. Stash dirty working tree if needed.
3. Checkout default branch (if not already on it).
4. `git pull --ff-only --prune` and record old/new HEAD.
5. Run `--before` hook if new commits were pulled.
6. Print changelog if new commits were pulled.
7. Checkout **target branch**.
8. `git rebase [--interactive] <default_branch>`.
9. Compute `changed` (pulled new commits OR rebase moved HEAD).
10. Run `--after` hook if `changed`.
11. Restore stash (we're on the target branch now).
12. Print summary.

### Degenerate case: target == current branch

When the user passes a branch name that matches `current_branch`, the script
sets `rebase=true` and follows the existing flow exactly. No special code path
needed — the target variable is unused and the script behaves as
`git up --rebase`.

### Degenerate case: no target branch (existing behavior)

Completely unchanged. The positional arg defaults to empty, `rebase` defaults
to `false`, and the existing flow runs.

## Hook behavior

- `--before CMD`: Fires on the default branch after pull, if new commits were
  pulled. Unchanged from today.
- `--after CMD`: Fires on the target branch (or current branch if no target)
  after rebase, if meaningful changes occurred. Unchanged semantics — just
  fires on a potentially different branch.

## Cleanup trap changes

The trap must account for a new variable: `target_branch`.

On unexpected failure:
- **Branch restoration**: If `target_branch` is set and differs from
  `current_branch`, the trap should try to return to `current_branch` (the
  starting point). Today the trap returns to `current_branch` when it differs
  from `default_branch` — the same logic applies, but the "where we want to
  end up on failure" is always the original starting branch.
- **Stash restoration**: Unchanged — pop stash on whichever branch we land on.
  If we can't get back to the right branch, warn the user to pop manually.

## Help text

```
Usage: git up [--rebase] [--interactive] [--before CMD] [--after CMD] [BRANCH]

Updates the default branch (main/master) from origin, then
returns to the branch you were on.  Dirty working trees are
auto-stashed and restored afterward.

Options:
  --rebase, -r          Rebase the current branch onto the default branch.
  --interactive, -i     Use interactive rebase (requires --rebase).
  -ri                   Same as --rebase --interactive.
  --before, -b CMD      Run CMD on the default branch after pulling.
                        Skipped if no new commits were pulled.
  --after, -a CMD       Run CMD on the current branch after the update.
                        Skipped if no meaningful changes occurred.
  -h                    Show this message.

Arguments:
  BRANCH                Target branch to rebase onto the updated default
                        branch. Implies --rebase. You will end up on BRANCH
                        after the operation completes.

Hook commands are passed to eval -- use only with trusted input.
--before fires when new commits are pulled.
--after fires when new commits are pulled or rebase moved commits.

Changelog of pulled commits is printed after the update.

Examples:
  git up --rebase
  git up --rebase --interactive
  git up --before "make build" --after "yarn install"
  git up -r -b "make" -a "yarn"
  git up feature-branch
  git up feature-branch --interactive
  git up feature-branch -b "make" -a "yarn"
```

## Error messages

| Condition | Message |
|-----------|---------|
| Target branch is the default branch | `git-up: target branch cannot be the default branch` |
| Target branch does not exist | `git-up: branch '<name>' does not exist` |
| Target branch + detached HEAD | Existing detached HEAD error fires first (no change needed) |

## Variables introduced

- `target_branch` — the branch name from the positional arg (empty if not given).

## Testing notes

The script is a `/bin/sh` script without a test harness. Manual verification:

1. `git up feature-branch` from main — pulls, rebases, lands on feature-branch.
2. `git up feature-branch` from feature-branch — behaves like `git up --rebase`.
3. `git up main` from feature-branch — errors: "target branch cannot be the default branch".
4. `git up nonexistent` — errors: "branch 'nonexistent' does not exist".
5. `git up feature-branch --interactive` — interactive rebase.
6. `git up feature-branch --before "echo hi" --after "echo bye"` — hooks fire.
7. Dirty working tree + `git up feature-branch` — stash/restore works.
8. Simulated failure mid-operation — trap returns to starting branch.
