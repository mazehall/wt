#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
wt="$repo_root/bin/wt"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export WT_HUB_ROOT="$tmp/hubs"
export WT_ROOT="$tmp/worktrees"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

if "$wt" init ../escape "$tmp/nonexistent" >/dev/null 2>&1; then
  fail 'wt init accepted a repo path containing ..'
fi
test ! -e "$tmp/escape.git" || fail 'wt init wrote outside WT_HUB_ROOT'

mkdir -p "$WT_HUB_ROOT"
git init --bare -q "$WT_HUB_ROOT/sample.git"

if "$wt" new sample ../escape --branch safe >/dev/null 2>&1; then
  fail 'wt new accepted a task path containing ..'
fi
test ! -e "$tmp/escape" || fail 'wt new wrote outside WT_ROOT'

if "$wt" rm sample ../escape >/dev/null 2>&1; then
  fail 'wt rm accepted a task path containing ..'
fi

if "$wt" new ../outside task >/dev/null 2>&1; then
  fail 'wt new accepted a repo path containing ..'
fi

git init -q "$tmp/source"
git -C "$tmp/source" config user.name test
git -C "$tmp/source" config user.email test@example.invalid
printf 'base\n' > "$tmp/source/file.txt"
git -C "$tmp/source" add file.txt
git -C "$tmp/source" commit -qm initial
git -C "$tmp/source" branch -M main
git init --bare -q "$tmp/origin.git"
git -C "$tmp/source" remote add origin "$tmp/origin.git"
git -C "$tmp/source" push -qu origin main
git --git-dir="$tmp/origin.git" symbolic-ref HEAD refs/heads/main

"$wt" init valid "$tmp/origin.git" >/dev/null 2>&1
"$wt" new valid dirty-long --base origin/main >/dev/null 2>&1
printf 'dirty\n' >> "$WT_ROOT/valid/dirty-long/file.txt"
if "$wt" rm valid dirty-long >/dev/null 2>&1; then
  fail 'wt rm removed a dirty worktree without --force'
fi
"$wt" rm --force valid dirty-long >/dev/null 2>&1
test ! -e "$WT_ROOT/valid/dirty-long" || fail 'wt rm --force left the dirty worktree'

"$wt" new valid dirty-short --base origin/main >/dev/null 2>&1
printf 'dirty\n' >> "$WT_ROOT/valid/dirty-short/file.txt"
"$wt" rm -f valid dirty-short >/dev/null 2>&1
test ! -e "$WT_ROOT/valid/dirty-short" || fail 'wt rm -f left the dirty worktree'
printf 'PASS: repo and task arguments stay within configured roots\n'
