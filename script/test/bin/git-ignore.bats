#!/usr/bin/env bats

setup() {
  load '../test_helper'
  GIT_IGNORE="$DOTFILES_ROOT/bin/git-ignore"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
  # Clear GIT_EDITOR so tests can inject an editor via EDITOR= without
  # the ambient GIT_EDITOR (set by editors/env.zsh) taking precedence.
  unset GIT_EDITOR
}

init_repo() {
  git init "$REPO" --quiet
  REPO="$(cd "$REPO" && pwd -P)"
  cd "$REPO"
  git config user.name "Test User"
  git config user.email "test@example.com"
}

@test "-h prints usage and exits 0" {
  run "$GIT_IGNORE" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git ignore"* ]]
}

@test "--help prints usage and exits 0" {
  run "$GIT_IGNORE" --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git ignore"* ]]
}

@test "path -l returns the local .gitignore path" {
  init_repo
  run "$GIT_IGNORE" path -l
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.gitignore" ]
}

@test "path -p returns the .git/info/exclude path" {
  init_repo
  run "$GIT_IGNORE" path -p
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.git/info/exclude" ]
}

@test "path defaults to local scope when no scope flag is given" {
  init_repo
  run "$GIT_IGNORE" path
  [ "$status" -eq 0 ]
  [ "$output" = "$REPO/.gitignore" ]
}

@test "path -g respects core.excludesFile" {
  export GIT_CONFIG_GLOBAL="$BATS_TEST_TMPDIR/global-config"
  : > "$GIT_CONFIG_GLOBAL"
  git config --global core.excludesFile "$BATS_TEST_TMPDIR/myignore"
  run "$GIT_IGNORE" path -g
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/myignore" ]
}

@test "path -g falls back to ~/.gitignore when core.excludesFile is unset" {
  HOME="$BATS_TEST_TMPDIR/home" mkdir -p "$BATS_TEST_TMPDIR/home"
  : > "$BATS_TEST_TMPDIR/home/.gitignore"
  HOME="$BATS_TEST_TMPDIR/home" run "$GIT_IGNORE" path -g
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/home/.gitignore" ]
}

@test "path -g falls back to XDG_CONFIG_HOME when neither is set" {
  local empty_home="$BATS_TEST_TMPDIR/empty-home"
  mkdir -p "$empty_home"
  HOME="$empty_home" XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/xdg" \
    run "$GIT_IGNORE" path -g
  [ "$status" -eq 0 ]
  [ "$output" = "$BATS_TEST_TMPDIR/xdg/git/ignore" ]
}

@test "path -l outside a repo exits 2" {
  cd "$BATS_TEST_TMPDIR"
  run "$GIT_IGNORE" path -l
  [ "$status" -eq 2 ]
  [[ "$output" == *"not in a git repo"* ]]
}

@test "conflicting scope flags exit 1" {
  init_repo
  run "$GIT_IGNORE" path -l -g
  [ "$status" -eq 1 ]
  [[ "$output" == *"conflicting scope"* ]]
}

@test "unknown subcommand exits 1" {
  run "$GIT_IGNORE" frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown subcommand"* ]]
}

@test "add writes patterns to .gitignore" {
  init_repo
  run "$GIT_IGNORE" add node_modules .env
  [ "$status" -eq 0 ]
  [ -f "$REPO/.gitignore" ]
  grep -Fxq "node_modules" "$REPO/.gitignore"
  grep -Fxq ".env" "$REPO/.gitignore"
}

@test "add prints a stderr summary by default" {
  init_repo
  run "$GIT_IGNORE" add node_modules
  [ "$status" -eq 0 ]
  [[ "$output" == *"added 1 pattern to .gitignore"* ]]
}

@test "add -q suppresses the summary" {
  init_repo
  run "$GIT_IGNORE" -q add node_modules
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "add is idempotent on duplicate patterns" {
  init_repo
  printf 'node_modules\n' > "$REPO/.gitignore"
  before=$(md5sum < "$REPO/.gitignore")
  run "$GIT_IGNORE" add node_modules
  [ "$status" -eq 0 ]
  after=$(md5sum < "$REPO/.gitignore")
  [ "$before" = "$after" ]
}

@test "add reports duplicates in the summary" {
  init_repo
  printf 'node_modules\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" add node_modules .env
  [ "$status" -eq 0 ]
  [[ "$output" == *"1 already present"* ]]
}

@test "add appends a trailing newline before writing" {
  init_repo
  printf 'existing-line' > "$REPO/.gitignore"   # no trailing \n
  run "$GIT_IGNORE" add new-line
  [ "$status" -eq 0 ]
  [ "$(cat "$REPO/.gitignore")" = "$(printf 'existing-line\nnew-line')" ]
  # Verify the file actually ends with a newline (command substitution can't see this)
  last_byte=$(tail -c 1 "$REPO/.gitignore" | od -An -tx1 | tr -d ' ')
  [ "$last_byte" = "0a" ]
}

@test "add creates the file if missing" {
  init_repo
  [ ! -e "$REPO/.gitignore" ]
  run "$GIT_IGNORE" add foo
  [ "$status" -eq 0 ]
  [ -f "$REPO/.gitignore" ]
}

@test "add -p creates .git/info/exclude path" {
  init_repo
  rm -f "$REPO/.git/info/exclude"
  run "$GIT_IGNORE" add -p '*.tmp'
  [ "$status" -eq 0 ]
  grep -Fxq '*.tmp' "$REPO/.git/info/exclude"
}

@test "add - reads patterns from stdin" {
  init_repo
  run bash -c "printf 'foo\nbar\n' | '$GIT_IGNORE' add -"
  [ "$status" -eq 0 ]
  grep -Fxq "foo" "$REPO/.gitignore"
  grep -Fxq "bar" "$REPO/.gitignore"
}

@test "add - skips blank lines and comments from stdin" {
  init_repo
  run bash -c "printf '# comment\n\nfoo\n  \nbar\n' | '$GIT_IGNORE' add -"
  [ "$status" -eq 0 ]
  grep -Fxq "foo" "$REPO/.gitignore"
  grep -Fxq "bar" "$REPO/.gitignore"
  ! grep -q '#' "$REPO/.gitignore"
  ! grep -qE '^\s*$' "$REPO/.gitignore"
}

@test "add with no patterns and no - is a usage error" {
  init_repo
  run "$GIT_IGNORE" add
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires patterns"* ]]
}

@test "add - with empty stdin is a no-op (exit 0)" {
  init_repo
  run bash -c ": | '$GIT_IGNORE' add -"
  [ "$status" -eq 0 ]
  [ ! -s "$REPO/.gitignore" ] || [ ! -e "$REPO/.gitignore" ]
}

@test "add rejects patterns containing literal newlines" {
  init_repo
  pat=$'line1\nline2'
  run "$GIT_IGNORE" add "$pat"
  [ "$status" -eq 1 ]
  [[ "$output" == *"newline"* ]]
}

@test "-- allows literal -foo as a pattern" {
  init_repo
  run "$GIT_IGNORE" add -- -foo
  [ "$status" -eq 0 ]
  grep -Fxq -- "-foo" "$REPO/.gitignore"
}

@test "rm removes an exact-match line" {
  init_repo
  printf 'foo\nbar\nbaz\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" rm bar
  [ "$status" -eq 0 ]
  [ "$(cat "$REPO/.gitignore")" = "$(printf 'foo\nbaz')" ]
}

@test "rm preserves comments and other lines" {
  init_repo
  printf '# top comment\nfoo\n# inline comment\nbar\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" rm foo
  [ "$status" -eq 0 ]
  grep -Fxq '# top comment' "$REPO/.gitignore"
  grep -Fxq '# inline comment' "$REPO/.gitignore"
  grep -Fxq 'bar' "$REPO/.gitignore"
  ! grep -Fxq 'foo' "$REPO/.gitignore"
}

@test "rm of a missing pattern is a no-op (exit 0)" {
  init_repo
  printf 'foo\n' > "$REPO/.gitignore"
  before=$(cat "$REPO/.gitignore")
  run "$GIT_IGNORE" rm not-there
  [ "$status" -eq 0 ]
  [ "$(cat "$REPO/.gitignore")" = "$before" ]
}

@test "rm reports counts in the summary" {
  init_repo
  printf 'foo\nbar\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" rm foo not-there
  [ "$status" -eq 0 ]
  [[ "$output" == *"removed 1 pattern from .gitignore"* ]]
  [[ "$output" == *"1 not found"* ]]
}

@test "rm of a missing file is a no-op" {
  init_repo
  run "$GIT_IGNORE" rm anything
  [ "$status" -eq 0 ]
  [ ! -e "$REPO/.gitignore" ]
  [[ "$output" == *"file does not exist"* ]]
}

@test "rm - reads patterns from stdin" {
  init_repo
  printf 'a\nb\nc\n' > "$REPO/.gitignore"
  run bash -c "printf 'a\nc\n' | '$GIT_IGNORE' rm -"
  [ "$status" -eq 0 ]
  [ "$(cat "$REPO/.gitignore")" = "b" ]
}

@test "rm -q suppresses the summary" {
  init_repo
  printf 'foo\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" -q rm foo
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "rm preserves file permissions even when no patterns match" {
  init_repo
  printf 'foo\n' > "$REPO/.gitignore"
  chmod 644 "$REPO/.gitignore"
  before=$(stat -f '%p' "$REPO/.gitignore" 2>/dev/null || stat -c '%a' "$REPO/.gitignore")
  run "$GIT_IGNORE" rm not-there
  [ "$status" -eq 0 ]
  after=$(stat -f '%p' "$REPO/.gitignore" 2>/dev/null || stat -c '%a' "$REPO/.gitignore")
  [ "$before" = "$after" ]
}

@test "list -l prints raw patterns from local" {
  init_repo
  printf 'foo\nbar\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" list -l
  [ "$status" -eq 0 ]
  [ "$output" = "$(printf 'foo\nbar')" ]
}

@test "list -l on missing file produces no output, exit 0" {
  init_repo
  run "$GIT_IGNORE" list -l
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "list --all (non-TTY) emits scope<TAB>pattern lines" {
  init_repo
  printf 'local-line\n' > "$REPO/.gitignore"
  printf 'private-line\n' > "$REPO/.git/info/exclude"
  run "$GIT_IGNORE" list --all
  [ "$status" -eq 0 ]
  [[ "$output" == *$'local\tlocal-line'* ]]
  [[ "$output" == *$'private\tprivate-line'* ]]
}

@test "list --all omits empty scopes" {
  init_repo
  printf 'only-local\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" list --all
  [ "$status" -eq 0 ]
  [[ "$output" == *$'local\tonly-local'* ]]
  ! [[ "$output" == *$'global\t'* ]]
  ! [[ "$output" == *$'private\t'* ]]
}

@test "bare git ignore is sugar for list --all" {
  init_repo
  printf 'foo\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE"
  [ "$status" -eq 0 ]
  [[ "$output" == *$'local\tfoo'* ]]
}

@test "list outside a repo with --all shows global only" {
  HOME="$BATS_TEST_TMPDIR/h"
  mkdir -p "$HOME"
  printf 'global-only\n' > "$HOME/.gitignore"
  cd "$BATS_TEST_TMPDIR"
  HOME="$HOME" run "$GIT_IGNORE" list --all
  [ "$status" -eq 0 ]
  [[ "$output" == *$'global\tglobal-only'* ]]
}

@test "list --all (non-TTY) filters blank lines and #-comments" {
  init_repo
  printf '# header comment\n\nfoo\n\n# inline comment\nbar\n' > "$REPO/.gitignore"
  run "$GIT_IGNORE" list --all
  [ "$status" -eq 0 ]
  [[ "$output" == *$'local\tfoo'* ]]
  [[ "$output" == *$'local\tbar'* ]]
  ! [[ "$output" == *'#'* ]]
  ! [[ "$output" == *$'local\t\n'* ]]
}

@test "list -l preserves comments and blank lines (round-trippable)" {
  init_repo
  contents=$'# header\n\nfoo\n\nbar\n'
  printf '%s' "$contents" > "$REPO/.gitignore"
  run "$GIT_IGNORE" list -l
  [ "$status" -eq 0 ]
  # cat strips no content; command substitution strips the final \n only
  [ "$output" = "$(printf '# header\n\nfoo\n\nbar')" ]
}

@test "edit -l opens the local gitignore in EDITOR" {
  init_repo
  EDITOR='echo OPENED:' run "$GIT_IGNORE" edit -l
  [ "$status" -eq 0 ]
  [[ "$output" == *"OPENED:"*"$REPO/.gitignore"* ]]
}

@test "edit -p opens the per-clone exclude in EDITOR" {
  init_repo
  EDITOR='echo OPENED:' run "$GIT_IGNORE" edit -p
  [ "$status" -eq 0 ]
  [[ "$output" == *"OPENED:"*"$REPO/.git/info/exclude"* ]]
}

@test "edit creates the file before opening" {
  init_repo
  [ ! -e "$REPO/.gitignore" ]
  EDITOR='true' run "$GIT_IGNORE" edit -l
  [ "$status" -eq 0 ]
  [ -f "$REPO/.gitignore" ]
}

@test "edit defaults to local without -l" {
  init_repo
  EDITOR='echo OPENED:' run "$GIT_IGNORE" edit
  [ "$status" -eq 0 ]
  [[ "$output" == *"OPENED:"*"$REPO/.gitignore"* ]]
}

@test "edit rejects --all" {
  init_repo
  run "$GIT_IGNORE" edit --all
  [ "$status" -eq 1 ]
  [[ "$output" == *"--all"* ]]
}
