---
name: wt-worktree
description: Create, list, sync and remove task worktrees with the wt bare-hub manager. Use whenever a new task, branch or isolated working copy of a Git project is needed.
license: Apache-2.0
compatibility: opencode, omp
metadata:
  tool: wt
  requires: bash, git
---

## What I do

Manage task worktrees with `wt`. Layout:

- Bare hub: `$WT_HUB_ROOT/<repo>.git` (default `$HOME/agentic/<repo>.git`), shared by all worktrees of that repo.
- Task worktree: `$WT_ROOT/<repo>/<task>` (default `$HOME/projects/<repo>/<task>`).

## Rules

- Create new task worktrees only with `wt new`. Never run `git worktree add` or `git clone` for this purpose.
- `wt new` prints the new worktree path on stdout and status messages on stderr. Capture the path and work inside it:
  `dir=$(wt new <repo> <task>)` then operate in `"$dir"`.
- Inside a managed worktree or project directory, the repo can be omitted: `wt new <task>`, `wt rm <task>`, `wt list`, `wt sync`, `wt prune`.
- `<task>` is a single path component. Use `--branch <name>` if the branch name must differ from the task directory name.
- Base ref: `--base <ref>`. Default is `origin/HEAD`, then `origin/main`, then `origin/master`.
- `wt` never deletes remote branches or refs. `wt rm` removes only the local worktree and, if fully merged, the local hub branch (never the hub default branch). Ending local work must not touch the remote.
- Never use `wt rm --force` without explicit user confirmation: it discards uncommitted changes.
- `wt rm` refuses to remove the worktree that contains the current directory. `cd` elsewhere first.
- Before removing, check for unpushed work (`git -C "$dir" status`, `git -C "$dir" log @{u}..`). Report findings rather than deleting silently.

## Commands

```text
wt new <repo> <task> [--branch <b>] [--base <ref>]   create worktree, print its path
wt new <task>                                        same, repo inferred from current project
wt list [<repo>]                                     list registered worktrees
wt sync [<repo>]                                     fetch updates for a hub
wt rm [--force] <repo> <task>                        remove clean worktree and its local branch if merged
wt rm [--force] <task>                               same, repo inferred
wt prune [<repo>]                                    prune stale worktree registrations
```

## Workflow

1. Determine repo and task name. If unclear, ask the user.
2. If the hub does not exist yet: `wt init <repo> <url-or-checkout>`.
3. Run `wt sync <repo>` if the hub may be stale.
4. `dir=$(wt new <repo> <task>)`, then continue the work in `"$dir"`.
5. When finished and pushed or merged: `wt rm <repo> <task>` from outside that worktree.

## Verification

After `wt new`, confirm with `wt list <repo>` that the path appears and `git -C "$dir" branch --show-current` shows the expected branch.
