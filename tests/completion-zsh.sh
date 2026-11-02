#!/usr/bin/env zsh
# Check zsh completion candidates without an interactive shell.
set -euo pipefail

if ! command -v zsh >/dev/null 2>&1; then
  print 'SKIP: zsh is not installed'
  exit 0
fi

repo_root="$(cd "$(dirname "$0")/.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
export WT_HUB_ROOT="$tmp/hubs"
export WT_ROOT="$tmp/worktrees"
export PATH="$repo_root/bin:$PATH"

mkdir -p "$WT_HUB_ROOT" "$WT_ROOT"
git init --bare -q "$WT_HUB_ROOT/alpha.git"
git init --bare -q "$WT_HUB_ROOT/beta.git"
mkdir -p "$WT_ROOT/alpha/task-one" "$WT_ROOT/alpha/task-two"
for dir in "$WT_ROOT"/alpha/*; do
  : > "$dir/.git"
done
mkdir -p "$WT_ROOT/standalone"
: > "$WT_ROOT/standalone/.git"

fpath=("$repo_root/completions" $fpath)
autoload -Uz compinit
compinit -u -d "$tmp/.zcompdump" >/dev/null 2>&1

typeset -ga completion_candidates
compadd() {
  local arg
  for arg in "$@"; do
    [[ "$arg" == -- ]] && continue
    completion_candidates+=("$arg")
  done
  return 0
}

complete_for() {
  local dir="$1"
  shift
  cd "$dir"
  completion_candidates=()
  words=("$@")
  CURRENT=$#
  _wt || true
  if (( ${#completion_candidates} )); then
    print -rl -- "${completion_candidates[@]}"
  fi
}

expect() {
  local label="$1" expected="$2" actual
  shift 2
  actual="$(complete_for "$@")"
  if [[ "$actual" != "$expected" ]]; then
    print -u2 "FAIL: $label"
    print -u2 "  expected: ${(qqq)expected}"
    print -u2 "  actual:   ${(qqq)actual}"
    exit 1
  fi
  print "PASS: $label"
}

expect 'commands' $'init\nsync\nnew\nlist\nrm\ncompletion\nprune' "$tmp" wt ''
expect 'sync hubs outside a project' $'alpha\nbeta' "$tmp" wt sync ''
expect 'sync hub prefix' 'alpha' "$tmp" wt sync a
expect 'sync --all flag' '--all' "$tmp" wt sync --
expect 'new flags' $'--repo\n--branch\n--base' "$tmp" wt new --
expect 'rm flags' $'--force\n-f' "$tmp" wt rm --
expect 'rm worktrees' $'task-one\ntask-two' "$tmp" wt rm alpha ''
expect 'new hubs outside a project' $'alpha\nbeta' "$tmp" wt new ''
expect 'init sources' 'standalone' "$tmp" wt init ''
expect 'new inside a project does not suggest hubs' '' "$WT_ROOT/alpha/task-one" wt new ''
expect 'rm inside a project suggests worktrees and hubs' $'task-one\ntask-two\nalpha\nbeta' "$WT_ROOT/alpha/task-one" wt rm ''
expect 'new --repo suggests hubs inside a project' $'alpha\nbeta' "$WT_ROOT/alpha/task-one" wt new --repo ''

print 'all zsh completion scenarios passed'
