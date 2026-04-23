# git-logme Redesign

**Date:** 2026-04-23
**Approach:** Smarter defaults (Approach 2)

## Problem

`git-logme` discovers your git identities and filters `git log` to show only your commits. The current implementation works but has UX and correctness gaps:

- Fragile identity discovery: sed-parses raw gitconfig for `path =` lines, which can match outside `[includeIf]` sections and doesn't handle quoting or whitespace correctly.
- No `-h` help text.
- No way to inspect discovered identities (the #1 debugging question is "why isn't my commit showing up?").
- No consistent error messaging pattern.
- Bare `git logme` gives raw `git log` output, which isn't optimized for the "what did I do?" question.

## Use Cases

1. **Standup prep / time-bounded review** — "What did I do today/this week?"
2. **Repo filtering** — "Show me just my commits in this busy repo."

Multi-identity support is a safety net (sometimes active, not always), but correctness matters — weird configs should still work.

## Design

### Identity Discovery

Replace sed-based config parsing with git's own config machinery:

1. **Global config** — `git config --global --get-all user.name` / `user.email`.
2. **Conditional includes** — `git config --file <global-config> --get-regexp 'includeif\..+\.path'` extracts all `includeIf` target paths using git's INI parser. Resolve `~` prefixes, then run `git config --file <path> --get-all user.name` / `user.email` on each.
3. **Repo-local config** — `git config --file "$(git rev-parse --git-dir)/config" --get-all user.name` / `user.email` (only when inside a repo).
4. **Dedup** — `sort -u` on the accumulated identities.

Store `identity<TAB>source` pairs in the tmpfile (not bare values) so `--list` can show provenance.

The tmpfile + trap cleanup pattern is retained.

### CLI Interface

```
Usage: git logme [--list] [--today] [--week] [--month] [<git-log-options>]
```

| Flag | Short | Behavior |
|------|-------|----------|
| `--list` | `-l` | Print discovered identities with source files, then exit. |
| `--today` | `-t` | Adds `--since="00:00"` to the git log call. |
| `--week` | `-w` | Adds `--since="1 week ago"` to the git log call. |
| `--month` | `-m` | Adds `--since="1 month ago"` to the git log call. |
| `-h` | | Show help text and exit. No `--help` (git intercepts it). |

Arg parsing consumes known flags, then passes everything remaining to `git log` via `"$@"`. Multiple time flags: last one wins. Time filters compose with user args (`git logme --week --stat` works).

### Default Format

When no format-related flags are present in the args, apply:

```
--color --format='%C(auto)%h %C(blue)%ad %C(auto)%s%C(dim)%d' --date=relative
```

Produces output like:
```
a1b2c3d  2 hours ago  fix login redirect  (HEAD -> feature/auth)
e4f5g6h  yesterday    add user migration
```

**Detection:** Skip default format if any arg in `"$@"` matches one of: `--oneline`, `--format=*`, `--pretty`, `--pretty=*`, `--raw`, `--patch`, `-p`, `--stat`, `--stat=*`, `--graph`. Check each arg individually (whole-arg match or prefix match for `=` variants).

**Color:** Respect `NO_COLOR` env var and tty detection, same as git-up. The `%C(auto)` in the format string respects git's own color settings.

### Helpers and Messaging

```sh
die()  { printf 'git-logme: %s\n' "$1" >&2; exit 1; }
warn() { printf 'git-logme: %s\n' "$1" >&2; }
```

Consistent `git-logme:` prefix on all stderr output.

**`--list` output:**
```
git-logme: discovered identities:
  Eric Baer                  (~/.gitconfig)
  eric@example.com           (~/.gitconfig)
  eric.baer@work.com         (~/.gitconfig.gusto)
```

Shows identity and source file. Exits after printing.

**No-identity error:** `die "no user identities found in git config"`.

### Help Text

```
Usage: git logme [--list] [--today] [--week] [--month] [<git-log-options>]

Shows your commits across all your configured git identities.
Discovers user.name and user.email from your global, conditional
include, and repo-local git configs automatically.

Options:
  --list, -l              Show discovered identities and exit.
  --today, -t             Commits since midnight.
  --week, -w              Commits from the last 7 days.
  --month, -m             Commits from the last 30 days.
  -h                      Show this message.

All other arguments are forwarded to git log.

When no format flags are given, a compact format with relative
dates is used. Pass --oneline, --format, --pretty, --stat, etc.
to override.

Examples:
  git logme
  git logme --today
  git logme --week --stat
  git logme --list
  git logme --since="2025-01-01" --oneline
```

### Shebang and Compatibility

`#!/usr/bin/env bash` — arrays are required for `author_args+=()`. Not portable to `/bin/sh`.

## Non-Goals

- Cross-repo scanning (run it in each repo).
- Group-by-day output or summary counts (adds complexity without enough value).
- `--help` long flag (git intercepts it for man pages).
