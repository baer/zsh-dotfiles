# git-up Target Branch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a positional `BRANCH` argument to `git up` that pulls the default branch and rebases the named branch onto it, landing the user on that branch.

**Architecture:** Single-file change to `bin/git-up`. A new `target_branch` variable is parsed from the first positional argument. After validation, it's normalized so that `target_branch` always holds "the branch we act on" (defaults to `current_branch` when omitted). The return-to-branch, rebase, and summary sections use `target_branch`; the cleanup trap uses `current_branch` (the starting point) for failure recovery.

**Tech Stack:** POSIX shell (`/bin/sh`), shellcheck for linting.

**Spec:** `docs/superpowers/specs/2026-04-24-git-up-target-branch-design.md`

---

### Task 1: Update help text

**Files:**
- Modify: `bin/git-up:67-98` (the `usage()` function)

- [ ] **Step 1: Update the usage() function**

Replace the entire `usage()` function body with updated text that adds `[BRANCH]` to the usage line, an `Arguments:` section, and new examples:

```sh
usage() {
  cat <<'EOF'
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

Hook commands are passed to eval — use only with trusted input.
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
EOF
  exit 0
}
```

- [ ] **Step 2: Run shellcheck**

Run: `shellcheck bin/git-up`
Expected: No new warnings (the existing SC2086 disable is still present later in the file).

- [ ] **Step 3: Commit**

```bash
git add bin/git-up
git commit -m "git-up: add BRANCH argument to help text"
```

---

### Task 2: Parse and validate target_branch

**Files:**
- Modify: `bin/git-up:122-153` (parse flags section and preflight section)

- [ ] **Step 1: Add target_branch variable and update argument parser**

In the parse flags section, add `target_branch=""` to the variable declarations and change the `*)` catch-all case to capture the first positional argument:

```sh
# -- parse flags -----------------------------------------------------

rebase=false
rebase_interactive=false
before_cmd=""
after_cmd=""
target_branch=""
while [ $# -gt 0 ]; do
  case "$1" in
    -h)                   usage ;;
    -ri)                  rebase=true; rebase_interactive=true; shift ;;
    -r|--rebase)          rebase=true; shift ;;
    -i|--interactive)     rebase_interactive=true; shift ;;
    --before|-b)          [ -n "${2:-}" ] || die "$1 requires a command argument"
                          before_cmd="$2"; shift 2 ;;
    --after|-a)           [ -n "${2:-}" ] || die "$1 requires a command argument"
                          after_cmd="$2"; shift 2 ;;
    -*)                   die "unknown option: $1 (see git up -h)" ;;
    *)                    [ -z "$target_branch" ] || die "unexpected argument: $1 (see git up -h)"
                          target_branch="$1"; shift ;;
  esac
done
```

Key changes from the original:
- Split `*)` into `-*)` for flags and `*)` for positional args.
- `-*)` catches anything starting with a dash — unknown flags error.
- `*)` captures the first positional arg into `target_branch`; a second positional arg errors.

- [ ] **Step 2: Add target_branch validation after preflight**

After the existing `default_branch` detection (line 151) and before the opening `printf` (line 153), add validation:

```sh
default_branch=$(detect_default_branch) \
  || die "could not determine default branch"

# -- validate target branch -------------------------------------------

if [ -n "$target_branch" ]; then
  git show-ref --verify --quiet "refs/heads/$target_branch" 2>/dev/null \
    || die "branch '$target_branch' does not exist"
  [ "$target_branch" != "$default_branch" ] \
    || die "target branch cannot be the default branch"
  if [ "$target_branch" = "$current_branch" ]; then
    # Already on the target — just enable rebase, no special handling
    target_branch=""
  fi
  rebase=true
fi

# Normalize: target_branch is always "the branch we act on"
if [ -z "$target_branch" ]; then
  target_branch="$current_branch"
fi
```

After this block, `target_branch` always holds the branch we want to end up on and potentially rebase. `current_branch` always holds where we started.

- [ ] **Step 3: Update opening message**

Replace the single `printf` line with a conditional that mentions the target when it differs from the starting branch:

```sh
if [ "$target_branch" != "$current_branch" ]; then
  printf 'git-up: updating %s from origin, targeting %s...\n' "$default_branch" "$target_branch"
else
  printf 'git-up: updating %s from origin...\n' "$default_branch"
fi
```

- [ ] **Step 4: Run shellcheck**

Run: `shellcheck bin/git-up`
Expected: Clean (no new warnings).

- [ ] **Step 5: Commit**

```bash
git add bin/git-up
git commit -m "git-up: parse and validate target branch positional argument"
```

---

### Task 3: Update main flow to use target_branch

**Files:**
- Modify: `bin/git-up:204-214` (return to branch)
- Modify: `bin/git-up:219` (rebase guard)
- Modify: `bin/git-up:300` (summary)

- [ ] **Step 1: Update the "return to branch" section**

Replace `current_branch` with `target_branch` in the checkout-back section. This is the section after the changelog, around line 204:

```sh
# -- go to target branch -----------------------------------------------

if [ "$target_branch" != "$default_branch" ]; then
  git checkout "$target_branch" || {
    warn "could not checkout '$target_branch' — staying on $default_branch"
    if $did_stash; then
      warn "your stash is preserved — run 'git stash pop' when ready"
    fi
    _exit_handled=true; exit 1
  }
fi
```

Also update the section comment from `# -- return to branch` to `# -- go to target branch` to reflect the new semantics.

- [ ] **Step 2: Update the rebase guard**

In the rebase section (around line 219), change the guard from `$current_branch` to `$target_branch`:

```sh
if $rebase && [ "$target_branch" != "$default_branch" ]; then
```

The rest of the rebase section is unchanged — `git rebase "$default_branch"` runs on whichever branch we're currently on, which is `target_branch`.

- [ ] **Step 3: Update the summary line**

In the summary section (around line 300), change:

```sh
$did_rebase_change && summary="$summary, rebased $current_branch onto $default_branch"
```

to:

```sh
$did_rebase_change && summary="$summary, rebased $target_branch onto $default_branch"
```

- [ ] **Step 4: Run shellcheck**

Run: `shellcheck bin/git-up`
Expected: Clean.

- [ ] **Step 5: Commit**

```bash
git add bin/git-up
git commit -m "git-up: route main flow through target_branch"
```

---

### Task 4: Update cleanup trap

**Files:**
- Modify: `bin/git-up:23-63` (the `_trap_exit` function)

The current trap only tries to restore the branch when `current_branch != default_branch`. This misses the new scenario where you start on main (current == default) but fail after checking out a target branch. The fix: check if we're actually on `current_branch`, regardless of what `default_branch` is.

- [ ] **Step 1: Replace the branch-restoration block in the trap**

Replace the "Try to return to the original branch" block (lines 32-49) with a simpler version that checks actual position:

```sh
  # Try to return to the original branch
  _restored_branch=false
  _on_branch=$(git symbolic-ref --short HEAD 2>/dev/null || true)
  if [ -n "${current_branch:-}" ] && [ "$_on_branch" != "${current_branch:-}" ]; then
    if git checkout "$current_branch" 2>/dev/null; then
      warn "returned to $current_branch"
      _restored_branch=true
    else
      warn "could not return to $current_branch — you are on ${_on_branch:-detached HEAD}"
    fi
  else
    _restored_branch=true
  fi
```

Key difference: instead of checking `current_branch != default_branch` and then `_on_branch == default_branch`, it simply checks `_on_branch != current_branch`. This covers:
- Started on feature-x, failed on main → return to feature-x (same as today)
- Started on main, targeting feature-x, failed on feature-x → return to main (new case)
- Started on main, failed on main → already there, skip (same as today)

- [ ] **Step 2: Run shellcheck**

Run: `shellcheck bin/git-up`
Expected: Clean.

- [ ] **Step 3: Commit**

```bash
git add bin/git-up
git commit -m "git-up: simplify trap to handle target-branch failure recovery"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Verify shellcheck passes**

Run: `shellcheck bin/git-up`
Expected: Clean (only the pre-existing SC2086 disable).

- [ ] **Step 2: Verify help text**

Run: `bin/git-up -h`
Expected: Updated help text with `[BRANCH]` in usage line, `Arguments:` section, and new examples.

- [ ] **Step 3: Verify error cases**

In any git repo:
- `git up nonexistent` → error: `branch 'nonexistent' does not exist`
- `git up main` (while on main) → error: `target branch cannot be the default branch`
- `git up branch1 branch2` → error: `unexpected argument: branch2`
- `git up --bogus` → error: `unknown option: --bogus`

- [ ] **Step 4: Verify happy path (target branch from main)**

```bash
# Setup: be on main with a feature branch that has commits
git checkout main
git up feature-branch
```

Expected:
- Pulls main
- Checks out feature-branch
- Rebases feature-branch onto main
- Ends up on feature-branch
- Summary mentions rebase

- [ ] **Step 5: Verify degenerate case (target == current)**

```bash
git checkout feature-branch
git up feature-branch
```

Expected: Behaves identically to `git up --rebase` — pulls main, rebases current branch, stays on it.

- [ ] **Step 6: Verify existing behavior unchanged**

```bash
git checkout feature-branch
git up
git up --rebase
git up --rebase --interactive
```

Expected: All behave exactly as before the change.
