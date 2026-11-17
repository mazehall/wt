#!/usr/bin/env bash
# Sync must advance only the unused hub default branch, preserving local work.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
wt="${WT_TEST_BIN:-$repo_root/bin/wt}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export WT_HUB_ROOT="$tmp/hubs"
export WT_ROOT="$tmp/worktrees"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.invalid

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

head_of() { git --git-dir="$WT_HUB_ROOT/$1.git" rev-parse "$2"; }
work_state() {
  git -C "$1" status --porcelain
  git -C "$1" diff
  git -C "$1" diff --cached
  cat "$1/untracked"
}

# Remote topic B has not yet been merged into main A.
git init -q -b main "$tmp/source"
printf 'base\n' > "$tmp/source/file"
git -C "$tmp/source" add file
git -C "$tmp/source" commit -qm initial
git init --bare -q "$tmp/origin.git"
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/main
git -C "$tmp/source" remote add origin "$tmp/origin.git"
git -C "$tmp/source" push -q origin main
git -C "$tmp/source" checkout -qb topic
printf 'merged change\n' >> "$tmp/source/file"
git -C "$tmp/source" commit -qam topic
git -C "$tmp/source" push -q origin topic
"$wt" init r "$tmp/origin.git"
"$wt" new r finished --branch topic
hub="$WT_HUB_ROOT/r.git"
git --git-dir="$hub" branch --set-upstream-to=origin/topic topic
"$wt" new r working --base origin/main
working="$WT_ROOT/r/working"
printf 'staged\n' >> "$working/file"
git -C "$working" add file
printf 'unstaged\n' >> "$working/file"
printf 'keep me\n' > "$working/untracked"
before="$(work_state "$working")"
working_head="$(head_of r working)"

# Merge the topic and delete its remote branch, as GitHub does after a PR.
git -C "$tmp/source" checkout -q main
git -C "$tmp/source" merge -q --ff-only topic
git -C "$tmp/source" push -q origin main :topic
merged="$(git -C "$tmp/source" rev-parse HEAD)"
(cd "$working" && "$wt" sync)
[ "$(head_of r main)" = "$merged" ] || fail 'hub main did not fast-forward'
[ "$(head_of r working)" = "$working_head" ] || fail 'task branch moved'
[ "$(work_state "$working")" = "$before" ] || fail 'task changes were altered'
"$wt" rm r finished
if git --git-dir="$hub" show-ref --verify --quiet refs/heads/topic; then
  fail 'merged topic was kept after its remote disappeared'
fi
[ ! -e "$WT_ROOT/r/finished" ] || fail 'finished worktree remains'
"$wt" sync r
[ "$(head_of r main)" = "$merged" ] || fail 'repeated sync moved main'
printf 'PASS: sync advances main, preserves task work, and enables merged-branch cleanup\n'

# A real main worktree must not have its branch moved behind its index.
"$wt" init checked "$tmp/origin.git"
"$wt" new checked on-main --branch main
checked="$WT_ROOT/checked/on-main"
printf 'staged main\n' >> "$checked/file"
git -C "$checked" add file
printf 'unstaged main\n' >> "$checked/file"
printf 'keep main\n' > "$checked/untracked"
checked_before="$(work_state "$checked")"
"$wt" init plain "$tmp/origin.git"

# A local-only commit must survive both ahead and diverged states.
local_commit="$(printf 'local work\n' | git --git-dir="$hub" commit-tree "$merged^{tree}" -p "$merged")"
git --git-dir="$hub" update-ref refs/heads/main "$local_commit" "$merged"
"$wt" sync r
[ "$(head_of r main)" = "$local_commit" ] || fail 'ahead main lost local work'
printf 'remote advance\n' >> "$tmp/source/file"
git -C "$tmp/source" commit -qam advance
git -C "$tmp/source" push -q origin main
remote="$(git -C "$tmp/source" rev-parse HEAD)"
"$wt" sync --all
[ "$(head_of r main)" = "$local_commit" ] || fail 'diverged main lost local work'
[ "$(head_of checked main)" = "$merged" ] || fail 'checked-out main moved'
[ "$(work_state "$checked")" = "$checked_before" ] || fail 'main worktree changes were altered'
[ "$(head_of plain main)" = "$remote" ] || fail 'sync --all did not advance the unused main'
for repo in r checked plain; do
  [ "$(head_of "$repo" origin/main)" = "$remote" ] || fail 'sync --all did not fetch every hub'
done
[ "$(work_state "$working")" = "$before" ] || fail 'sync --all altered task changes'
printf 'PASS: ahead, diverged, and checked-out branches are preserved; --all still fetches every hub\n'

# A deleted remote default branch must not cause a fallback to another branch.
git --git-dir="$tmp/origin.git" config receive.denyDeleteCurrent ignore
git -C "$tmp/source" push -q origin :main
"$wt" sync plain
[ "$(head_of plain main)" = "$remote" ] || fail 'missing remote main changed local main'
printf 'PASS: missing remote default branch preserves local history\n'
