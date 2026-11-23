#!/usr/bin/env bash
# wt rm must work with read-only files, keep unmerged/default branches, and never touch the remote.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
wt="$repo_root/bin/wt"
tmp="$(mktemp -d)"
trap 'chmod -R u+w "$tmp" 2>/dev/null || true; rm -rf "$tmp"' EXIT
export WT_HUB_ROOT="$tmp/hubs"
export WT_ROOT="$tmp/worktrees"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

git init -q -b main "$tmp/source"
git -C "$tmp/source" commit -q --allow-empty -m init
git init --bare -q "$tmp/origin.git"
git -C "$tmp/source" remote add origin "$tmp/origin.git"
git -C "$tmp/source" push -q origin main
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/main
"$wt" init r "$tmp/origin.git" >/dev/null 2>&1

hub="$WT_HUB_ROOT/r.git"
"$wt" new r merged --base origin/main >/dev/null 2>&1
"$wt" new r unmerged --base origin/main >/dev/null 2>&1
"$wt" new r on-main --base origin/main --branch main >/dev/null 2>&1 || true

# Read-only tree (like envtest binaries / Go module cache) must not block removal.
mkdir -p "$WT_ROOT/r/merged/ro"
touch "$WT_ROOT/r/merged/ro/f"
chmod -R a-w "$WT_ROOT/r/merged/ro"
echo u > "$WT_ROOT/r/unmerged/u.txt"
git -C "$WT_ROOT/r/unmerged" add u.txt
git -C "$WT_ROOT/r/unmerged" commit -q -m unmerged-work

before="$(git --git-dir="$tmp/origin.git" for-each-ref)"
cd "$tmp"

"$wt" rm --force r merged >/dev/null 2>&1 || fail 'wt rm failed on read-only files'
test ! -e "$WT_ROOT/r/merged" || fail 'worktree dir still present after wt rm'
git --git-dir="$hub" rev-parse --verify --quiet refs/heads/merged >/dev/null \
  && fail 'merged local branch was kept'

"$wt" rm --force r unmerged >/dev/null 2>&1 || fail 'wt rm failed for unmerged worktree'
git --git-dir="$hub" rev-parse --verify --quiet refs/heads/unmerged >/dev/null \
  || fail 'unmerged local branch was deleted'

# Squash-merged branch: content lands in main with a different SHA; must be deleted.
"$wt" new r squashed --base origin/main >/dev/null 2>&1
echo a > "$WT_ROOT/r/squashed/a.txt"
git -C "$WT_ROOT/r/squashed" add a.txt
git -C "$WT_ROOT/r/squashed" commit -q -m feat
git -C "$tmp/source" fetch -q origin
git -C "$tmp/source" checkout -q main
echo a > "$tmp/source/a.txt"
git -C "$tmp/source" add a.txt
git -C "$tmp/source" commit -q -m "squash feat"
git -C "$tmp/source" push -q origin main
git --git-dir="$hub" fetch -q origin main:main 2>/dev/null || git --git-dir="$hub" fetch -q origin
before="$(git --git-dir="$tmp/origin.git" for-each-ref)"
"$wt" rm r squashed >/dev/null 2>&1 || fail 'wt rm failed for squashed worktree'
git --git-dir="$hub" rev-parse --verify --quiet refs/heads/squashed >/dev/null \
  && fail 'squash-merged local branch was kept'

# Branch contained in another remote branch (not the hub HEAD) is safe to delete.
"$wt" new r viarelease --base origin/main >/dev/null 2>&1
echo r > "$WT_ROOT/r/viarelease/r.txt"
git -C "$WT_ROOT/r/viarelease" add r.txt
git -C "$WT_ROOT/r/viarelease" commit -q -m rel
git -C "$WT_ROOT/r/viarelease" push -q origin HEAD:refs/heads/release/v2
git --git-dir="$hub" fetch -q origin
before="$(git --git-dir="$tmp/origin.git" for-each-ref)"
"$wt" rm r viarelease >/dev/null 2>&1 || fail 'wt rm failed for viarelease worktree'
git --git-dir="$hub" rev-parse --verify --quiet refs/heads/viarelease >/dev/null \
  && fail 'branch contained in remote release branch was kept'

after="$(git --git-dir="$tmp/origin.git" for-each-ref)"
test "$before" = "$after" || fail 'remote refs changed'

printf 'ok\n'
