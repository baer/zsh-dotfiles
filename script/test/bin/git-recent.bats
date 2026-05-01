#!/usr/bin/env bats

setup() {
  load '../test_helper'
  GIT_RECENT="$DOTFILES_ROOT/bin/git-recent"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
  export GIT_CONFIG_NOSYSTEM=1
  unset GIT_PAGER
  unset GIT_AUTHOR_DATE GIT_COMMITTER_DATE
}

init_repo() {
  git init "$REPO" --quiet --initial-branch=main
  REPO="$(cd "$REPO" && pwd -P)"
  cd "$REPO"
  git config user.name "Test User"
  git config user.email "test@example.com"
  # Pin main's initial commit to a fixed past date so ordering tests are
  # deterministic regardless of wall-clock time.
  GIT_AUTHOR_DATE="@900000000 +0000" GIT_COMMITTER_DATE="@900000000 +0000" \
    git commit --allow-empty -m "init" --quiet
}

make_branch() {
  local name="$1" ts="$2" subj="${3:-touch $name}"
  git checkout -q -b "$name"
  GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
    git commit --allow-empty -m "$subj" --quiet
  git checkout -q main
}

@test "-h prints usage and exits 0" {
  run "$GIT_RECENT" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git recent"* ]]
}

@test "--help prints usage and exits 0" {
  run "$GIT_RECENT" --help
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git recent"* ]]
}

@test "unknown flag exits 1 with helpful error" {
  run "$GIT_RECENT" --frobnicate
  [ "$status" -eq 1 ]
  [[ "$output" == *"unknown option"* ]]
}

@test "lists branches newest-first when piped (plain refnames)" {
  init_repo
  make_branch oldest 1000000000
  make_branch middle 1100000000
  make_branch newest 1200000000
  run "$GIT_RECENT"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "newest" ]
  [ "${lines[1]}" = "middle" ]
  [ "${lines[2]}" = "oldest" ]
  # main is pinned to 1998 by init_repo, so it sorts last — but it must
  # still appear in the output.
  [[ " ${lines[*]} " == *" main "* ]]
}

@test "no branches → exit 0, empty output" {
  # Empty git repo with no commits has no branches yet
  git init "$REPO" --quiet --initial-branch=main
  cd "$REPO"
  run "$GIT_RECENT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "-r reverses sort to oldest-first" {
  init_repo
  make_branch oldest 1000000000
  make_branch newest 1200000000
  run "$GIT_RECENT" -r
  [ "$status" -eq 0 ]
  # main pinned to 1998 → sorts first when reversed.
  [ "${lines[0]}" = "main" ]
  [ "${lines[1]}" = "oldest" ]
  [ "${lines[2]}" = "newest" ]
}

@test "--reverse is an alias for -r" {
  init_repo
  make_branch a 1000000000
  make_branch b 1200000000
  run "$GIT_RECENT" --reverse
  [ "$status" -eq 0 ]
  # First non-main line should be the older branch.
  [ "${lines[0]}" = "main" ]
  [ "${lines[1]}" = "a" ]
  [ "${lines[2]}" = "b" ]
}

@test "-n N limits output to N branches" {
  init_repo
  make_branch a 1000000000
  make_branch b 1100000000
  make_branch c 1200000000
  run "$GIT_RECENT" -n 2
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[0]}" = "c" ]
  [ "${lines[1]}" = "b" ]
}

@test "--limit N is an alias for -n" {
  init_repo
  make_branch a 1000000000
  run "$GIT_RECENT" --limit 1
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
}

@test "-n requires a numeric argument" {
  init_repo
  run "$GIT_RECENT" -n notanumber
  [ "$status" -eq 1 ]
  [[ "$output" == *"requires a number"* ]]
}

@test "-n 0 is allowed (prints nothing)" {
  init_repo
  make_branch a 1000000000
  run "$GIT_RECENT" -n 0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "--pretty forces columnar output even when piped" {
  init_repo
  make_branch feature 1200000000 "add feature X"
  run "$GIT_RECENT" --pretty
  [ "$status" -eq 0 ]
  # First non-main line should match the columnar layout.
  # Format: "YYYY-MM-DD <marker> <branch> <upstream> <hash> <subject>"
  # 3 literal spaces = separator + empty marker column (' ') + separator.
  # Fails if the marker column is removed (only 2 spaces between date and branch).
  [[ "${lines[0]}" =~ ^2008-01-10[[:space:]][[:space:]][[:space:]]feature[[:space:]] ]]
  [[ "${lines[0]}" == *"add feature X" ]]
}

@test "--pretty marks the current branch with *" {
  init_repo
  make_branch feature 1200000000
  git checkout -q feature
  run "$GIT_RECENT" --pretty
  [ "$status" -eq 0 ]
  # The line for `feature` should have a `*` in the marker column.
  for line in "${lines[@]}"; do
    if [[ "$line" == *" feature "* ]]; then
      [[ "$line" == *"* feature"* ]]
      return
    fi
  done
  false
}

@test "--plain forces refnames-only even on TTY" {
  init_repo
  make_branch feature 1200000000
  run "$GIT_RECENT" --plain
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "feature" ]
  [ "${lines[1]}" = "main" ]
}

@test "--color=always emits ANSI escapes" {
  init_repo
  make_branch feature 1200000000
  run "$GIT_RECENT" --pretty --color=always
  [ "$status" -eq 0 ]
  # Check for an ESC byte (0x1b) — bash $'\x1b' is the ESC char.
  [[ "$output" == *$'\x1b'* ]]
}

@test "--color=never emits no ANSI escapes" {
  init_repo
  make_branch feature 1200000000
  run "$GIT_RECENT" --pretty --color=never
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\x1b'* ]]
}

@test "NO_COLOR with --color=auto emits no escapes" {
  # NOTE: bats's `run` makes `[ -t 1 ]` false inside the script, so
  # --color=auto already resolves to "off" via the pipe path. We can't
  # exercise the NO_COLOR branch in isolation without a pseudo-TTY.
  # This test asserts the integrated behavior (no escapes when both
  # NO_COLOR and the pipe path agree) — the explicit-override cases
  # are tested by --color=always and --color=never above.
  init_repo
  make_branch feature 1200000000
  NO_COLOR=1 run "$GIT_RECENT" --pretty --color=auto
  [ "$status" -eq 0 ]
  [[ "$output" != *$'\x1b'* ]]
}

@test "--color=invalid exits 1" {
  init_repo
  run "$GIT_RECENT" --color=banana
  [ "$status" -eq 1 ]
  [[ "$output" == *"--color"* ]]
}

@test "--pretty aligns branch and upstream columns" {
  init_repo
  # Use branch names with non-hex chars (hyphens) so they cannot be matched
  # by the hash regex [0-9a-f]{7,12}. Different lengths to exercise padding.
  make_branch short-x 1000000000
  make_branch much-longer-branch-name 1100000000
  run "$GIT_RECENT" --pretty --color=never
  [ "$status" -eq 0 ]
  # Find lines where the short-hash field — 7+ hex chars surrounded by spaces
  # — appears, and collect everything before it as a "prefix" string.
  local hash_offsets=()
  for line in "${lines[@]}"; do
    # Look for the short-hash field — 7+ hex chars surrounded by spaces.
    if [[ "$line" =~ \ ([0-9a-f]{7,12})\  ]]; then
      hash_offsets+=("${line%% ${BASH_REMATCH[1]} *}")
    fi
  done
  # All hash_offsets entries should have the same length.
  local first_len=${#hash_offsets[0]}
  for off in "${hash_offsets[@]}"; do
    [ "${#off}" -eq "$first_len" ]
  done
}

@test "--pretty truncates subject to fit COLUMNS" {
  init_repo
  make_branch feature 1200000000 "this is a very long commit subject that should get truncated way before the end"
  COLUMNS=60 run "$GIT_RECENT" --pretty --color=never
  [ "$status" -eq 0 ]
  for line in "${lines[@]}"; do
    [ "${#line}" -le 60 ]
  done
}

@test "--pretty does not truncate when COLUMNS is unset and not a TTY" {
  init_repo
  make_branch feature 1200000000 "$(printf 'x%.0s' {1..200})"
  unset COLUMNS
  run "$GIT_RECENT" --pretty --color=never
  [ "$status" -eq 0 ]
  # The 200-x subject should appear in full somewhere (match 190 x's as a
  # safe substring — the glob just needs to confirm no truncation occurred).
  [[ "$output" == *"xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"* ]]
}

make_remote_tracking() {
  # Create a fake remote-tracking ref by pointing it at a new commit on top of HEAD.
  # $1=name (e.g. origin/foo)  $2=epoch
  local name="$1" ts="$2"
  local sha
  sha=$(GIT_AUTHOR_DATE="@$ts +0000" GIT_COMMITTER_DATE="@$ts +0000" \
        git commit-tree HEAD^{tree} -m "remote tip $name" -p HEAD)
  git update-ref "refs/remotes/$name" "$sha"
}

@test "default does not include remote-tracking branches" {
  init_repo
  make_remote_tracking origin/feat 1200000000
  run "$GIT_RECENT"
  [ "$status" -eq 0 ]
  [[ "$output" != *"origin/feat"* ]]
}

@test "-a includes remote-tracking branches" {
  init_repo
  make_branch local-br 1100000000
  make_remote_tracking origin/feat 1200000000
  run "$GIT_RECENT" -a
  [ "$status" -eq 0 ]
  [[ "${lines[*]}" == *"origin/feat"* ]]
  [[ "${lines[*]}" == *"local-br"* ]]
}

@test "--all is an alias for -a" {
  init_repo
  make_remote_tracking origin/feat 1200000000
  run "$GIT_RECENT" --all
  [[ "$output" == *"origin/feat"* ]]
}
