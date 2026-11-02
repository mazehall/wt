#!/usr/bin/env bash
# Runs inside the install-test container (see install-docker.sh).
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }
raw="https://raw.githubusercontent.com/mazehall/wt/main/install.sh"

git config --global user.email test@example.invalid
git config --global user.name test

# 1. One-liner as root installs and links into /usr/local/bin.
curl -fsSL "$raw" | bash >/dev/null
[ "$(readlink /usr/local/bin/wt)" = /root/.local/share/wt/bin/wt ] || fail "root link"
pass "one-liner installs and links into /usr/local/bin"

# 2. Smoke: init from a local repo, wt new prints only the path on stdout.
mkdir /tmp/src && (cd /tmp/src && git init -q -b main && echo a > a && git add a && git commit -qm init)
wt init demo /tmp/src >/dev/null 2>&1
dir="$(wt new demo t1 2>/dev/null)"
[ "$dir" = /root/projects/demo/t1 ] || fail "wt new stdout is '$dir'"
[ -f "$dir/a" ] || fail "worktree content missing"
pass "wt init and wt new; stdout is the worktree path"

# 3. Update: install an older ref, then rerun the one-liner; hubs survive.
WT_REF=0dbdeb5 bash /repo/install.sh >/dev/null
grep -q 'gh repo clone' /root/.local/share/wt/README.md || fail "old ref not installed"
curl -fsSL "$raw" | bash >/dev/null
grep -q 'tests/install-docker.sh' /root/.local/share/wt/README.md || fail "rerun did not update to main"
out="$(wt list demo)"
case "$out" in *t1*) ;; *) fail "hub or worktree lost on update" ;; esac
pass "rerun updates WT_HOME; hub and worktrees survive"

# 4. Non-root user with ~/.local/bin not on PATH.
useradd -m tester
runuser -u tester -- env PATH=/usr/bin:/bin bash /repo/install.sh >/tmp/tester.log 2>&1
grep -q 'is not on PATH' /tmp/tester.log || fail "missing PATH hint for tester"
[ "$(readlink /home/tester/.local/bin/wt)" = /home/tester/.local/share/wt/bin/wt ] || fail "tester link"
out="$(runuser -u tester -- env PATH=/home/tester/.local/bin:/usr/bin:/bin wt completion bash)"
[ -n "$out" ] || fail "completion empty for tester"
pass "non-root install links into ~/.local/bin and completions resolve"

echo "all install scenarios passed"
