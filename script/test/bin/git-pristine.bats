#!/usr/bin/env bats

setup() {
  load '../test_helper'
  PRISTINE="$DOTFILES_ROOT/bin/git-pristine"
  REPO="$BATS_TEST_TMPDIR/repo"
  export GIT_CONFIG_GLOBAL=/dev/null
}

init_repo() {
  git init "$REPO" --quiet
  cd "$REPO"
  git config user.name "Test User"
  git config user.email "test@example.com"
  printf 'tracked\n' > tracked.txt
  git add tracked.txt
  git commit -m "initial" --quiet
}

make_dirty() {
  printf 'changed\n' > tracked.txt
  printf 'untracked\n' > untracked.txt
}

@test "-h prints usage and exits 0" {
  run "$PRISTINE" -h
  [ "$status" -eq 0 ]
  [[ "${lines[0]}" == "Usage: git pristine"* ]]
  [[ "$output" != *"--help"* ]]
}

@test "outside a git repo exits 1 with message" {
  mkdir -p "$REPO"
  cd "$REPO"

  run "$PRISTINE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"not inside a git worktree"* ]]
}

@test "clean repo exits 0 and reports already pristine" {
  init_repo

  run "$PRISTINE"
  [ "$status" -eq 0 ]
  [[ "$output" == *"already pristine"* ]]
}

@test "default resets tracked changes and removes untracked files but preserves ignored files" {
  init_repo
  printf '*.ignored\n' > .gitignore
  git add .gitignore
  git commit -m "ignore pattern" --quiet

  printf 'changed\n' > tracked.txt
  printf 'staged\n' > staged.txt
  git add staged.txt
  mkdir untracked-dir
  printf 'untracked\n' > untracked-dir/file.txt
  printf 'ignored\n' > local.ignored

  run "$PRISTINE" -f
  [ "$status" -eq 0 ]
  [ "$(cat tracked.txt)" = "tracked" ]
  [ ! -e staged.txt ]
  [ ! -e untracked-dir ]
  [ -e local.ignored ]
}

@test "-x removes ignored files too" {
  init_repo
  printf '*.ignored\n' > .gitignore
  git add .gitignore
  git commit -m "ignore pattern" --quiet
  printf 'ignored\n' > local.ignored

  run "$PRISTINE" -fx
  [ "$status" -eq 0 ]
  [ ! -e local.ignored ]
}

@test "combined short flags work for no-argument options" {
  init_repo
  make_dirty

  run "$PRISTINE" -fn
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run only; no changes made"* ]]
  [ "$(cat tracked.txt)" = "changed" ]
  [ -e untracked.txt ]

  printf '*.ignored\n' > .gitignore
  git add .gitignore
  git commit -m "ignore pattern" --quiet
  printf 'ignored\n' > local.ignored

  run "$PRISTINE" -nx
  [ "$status" -eq 0 ]
  [[ "$output" == *"clean mode: untracked and ignored files included"* ]]
  [[ "$output" == *"Would remove local.ignored"* ]]
  [ -e local.ignored ]

  run "$PRISTINE" -fnx
  [ "$status" -eq 0 ]
  [[ "$output" == *"clean mode: untracked and ignored files included"* ]]
  [[ "$output" == *"dry run only; no changes made"* ]]
  [ -e local.ignored ]
}

@test "clustered argument-taking options are rejected" {
  init_repo

  run "$PRISTINE" -kfoo
  [ "$status" -eq 1 ]
  [[ "$output" == *"option -k requires a separate pattern argument"* ]]

  run "$PRISTINE" -fkfoo
  [ "$status" -eq 1 ]
  [[ "$output" == *"option -k requires a separate pattern argument"* ]]
}

@test "--exclude preserves matching untracked path" {
  init_repo
  mkdir keep-dir remove-dir
  printf 'keep\n' > keep-dir/file.txt
  printf 'remove\n' > remove-dir/file.txt

  run "$PRISTINE" -f --exclude keep-dir
  [ "$status" -eq 0 ]
  [ -e keep-dir/file.txt ]
  [ ! -e remove-dir ]

  run "$PRISTINE" -f --exclude keep-dir
  [ "$status" -eq 0 ]
  [[ "$output" == *"already pristine"* ]]
}

@test "--keep preserves matching untracked path" {
  init_repo
  mkdir keep-dir remove-dir
  printf 'keep\n' > keep-dir/file.txt
  printf 'remove\n' > remove-dir/file.txt

  run "$PRISTINE" -f --keep keep-dir
  [ "$status" -eq 0 ]
  [ -e keep-dir/file.txt ]
  [ ! -e remove-dir ]
}

@test "--keep supports git clean glob patterns" {
  init_repo
  mkdir -p tmp/cache tmp/log
  printf 'keep\n' > tmp/cache/file.txt
  printf 'remove\n' > tmp/log/file.txt

  run "$PRISTINE" -f --keep 'tmp/cache/**'
  [ "$status" -eq 0 ]
  [ -e tmp/cache/file.txt ]
  [ ! -e tmp/log ]
}

@test "preview shows keep patterns" {
  init_repo
  mkdir -p tmp/cache
  printf 'keep\n' > .env
  printf 'keep\n' > tmp/cache/file.txt
  printf 'remove\n' > remove.txt

  run "$PRISTINE" -n --keep .env --keep 'tmp/cache/**'
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-pristine: keep/exclude patterns:"* ]]
  [[ "$output" == *"  .env"* ]]
  [[ "$output" == *"  tmp/cache/**"* ]]
  [[ "$output" == *"patterns are passed to git clean -e; tracked files are still reset by git reset --hard"* ]]
}

@test "-n previews without changing tracked or untracked files" {
  init_repo
  printf 'changed\n' > tracked.txt
  printf 'untracked\n' > untracked.txt

  run "$PRISTINE" -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"dry run only; no changes made"* ]]
  [ "$(cat tracked.txt)" = "changed" ]
  [ -e untracked.txt ]
}

@test "non-interactive stdin without --force exits clearly and preserves files" {
  init_repo
  make_dirty

  run "$PRISTINE"
  [ "$status" -eq 1 ]
  [[ "$output" == *"refusing to prompt because stdin is not a TTY"* ]]
  [ "$(cat tracked.txt)" = "changed" ]
  [ -e untracked.txt ]
}

@test "-f runs without stdin confirmation" {
  init_repo
  printf 'changed\n' > tracked.txt

  run "$PRISTINE" -f
  [ "$status" -eq 0 ]
  [ "$(cat tracked.txt)" = "tracked" ]
}

@test "detached HEAD preview includes short SHA" {
  init_repo
  short_sha=$(git rev-parse --short HEAD)
  git checkout --detach --quiet
  make_dirty

  run "$PRISTINE" -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-pristine: ref: detached HEAD at $short_sha"* ]]
}

@test "in-progress merge state is detected and shown" {
  init_repo
  base_branch=$(git symbolic-ref --short HEAD)

  git checkout -b feature --quiet
  printf 'feature\n' > tracked.txt
  git commit -am "feature change" --quiet
  git checkout "$base_branch" --quiet
  printf 'base\n' > tracked.txt
  git commit -am "base change" --quiet
  git merge feature >/dev/null 2>&1 || true

  run "$PRISTINE" -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"git-pristine: in-progress operation:"* ]]
  [[ "$output" == *"  merge"* ]]
}

@test "--force warns before discarding in-progress merge state" {
  init_repo
  base_branch=$(git symbolic-ref --short HEAD)

  git checkout -b feature --quiet
  printf 'feature\n' > tracked.txt
  git commit -am "feature change" --quiet
  git checkout "$base_branch" --quiet
  printf 'base\n' > tracked.txt
  git commit -am "base change" --quiet
  git merge feature >/dev/null 2>&1 || true

  run "$PRISTINE" -f
  [ "$status" -eq 0 ]
  [[ "$output" == *"force mode: discarding in-progress operation state: merge"* ]]
  [ ! -f "$(git rev-parse --git-path MERGE_HEAD)" ]
}

@test "in-progress rebase cherry-pick and revert states are detected and shown" {
  init_repo
  mkdir -p "$(git rev-parse --git-path rebase-merge)"
  printf '%s\n' "$(git rev-parse HEAD)" > "$(git rev-parse --git-path CHERRY_PICK_HEAD)"
  printf '%s\n' "$(git rev-parse HEAD)" > "$(git rev-parse --git-path REVERT_HEAD)"
  make_dirty

  run "$PRISTINE" -n
  [ "$status" -eq 0 ]
  [[ "$output" == *"  rebase"* ]]
  [[ "$output" == *"  cherry-pick"* ]]
  [[ "$output" == *"  revert"* ]]
}

@test "--keep tracked.txt does not preserve tracked modifications" {
  init_repo
  printf 'changed\n' > tracked.txt

  run "$PRISTINE" -f --keep tracked.txt
  [ "$status" -eq 0 ]
  [ "$(cat tracked.txt)" = "tracked" ]
  [[ "$output" == *"tracked files are still reset by git reset --hard"* ]]
}

@test "--ignored preview explicitly mentions ignored files" {
  init_repo
  printf '*.ignored\n' > .gitignore
  git add .gitignore
  git commit -m "ignore pattern" --quiet
  printf 'ignored\n' > local.ignored

  run "$PRISTINE" --dry-run --ignored
  [ "$status" -eq 0 ]
  [[ "$output" == *"clean mode: untracked and ignored files included"* ]]
  [[ "$output" == *"Would remove local.ignored"* ]]
}
