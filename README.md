# `wt` — bare-hub Git worktree manager

`wt` keeps one bare clone per repository and creates sibling worktrees for individual tasks:

```text
$HOME/agentic/<repo>.git       bare Git hub
$HOME/projects/<repo>/<task>   working tree
```

Set `WT_HUB_ROOT` or `WT_ROOT` to change either location. The tool is a Bash script and requires Git. `gh` is optional; when available and authenticated, `wt init` configures GitHub's host-specific credential helper for HTTPS remotes.

## Install

Requires `curl`, `tar`, and `git`. Install `wt` with:

```bash
curl -fsSL https://raw.githubusercontent.com/mazehall/wt/main/install.sh | bash
```

The installer downloads the repository archive into `~/.local/share/wt` and links `bin/wt` into the directory of an existing `wt` symlink, or else the first writable directory on `PATH` among `~/.local/bin`, `~/bin`, `/opt/homebrew/bin`, and `/usr/local/bin`. If none is on `PATH`, it creates `~/.local/bin` and prints the line to add to your shell profile. Rerun it to update. Set `WT_HOME` to change the install location and `WT_REF` to install another branch or tag.

`wt completion <shell>` prints completion definitions for Fish, Bash, or Zsh. Install them with:

```sh
# Fish
mkdir -p ~/.config/fish/completions
wt completion fish > ~/.config/fish/completions/wt.fish

# Bash (source ~/.bash_completion from your shell startup file if not already done)
wt completion bash >> ~/.bash_completion

# Zsh (add these lines to ~/.zshrc once)
mkdir -p ~/.zfunc
wt completion zsh > ~/.zfunc/_wt
fpath=(~/.zfunc $fpath)
autoload -Uz compinit && compinit
```

Restart the shell or reload its completion setup after installing.

## Commands

```text
wt init <repo> <url-or-checkout>  Create a bare hub and fetch its refs
wt new <repo> <task>              Create a task worktree
wt new <task>                     Create a worktree for the current project
wt new --repo <repo> <task>       Select a project explicitly
wt sync [<repo>]                  Fetch updates for a hub
wt sync --all                     Fetch every hub
wt list [<repo>]                  List registered worktrees
wt rm [--force] <repo> <task>     Remove a clean worktree and its branch
wt rm [--force] <task>            Remove a worktree for the current project
wt completion <fish|bash|zsh>     Print shell completion source
wt prune [<repo>]                 Prune stale worktree registrations
```

Inside a managed worktree, `wt new <task>`, `wt rm <task>`, `wt sync`, `wt list`, and `wt prune` infer the project from Git metadata. When run from a project grouping directory, the hub name is inferred under `WT_ROOT`.

The task name is one path component; use `--branch` to choose a branch name that differs from the task directory. `--base` selects a base ref; otherwise `wt` uses `origin/HEAD`, then `origin/main` or `origin/master`.

## Design notes

- Bare hubs share one Git object store among all task worktrees.
- `wt` sets the bare clone's fetch refspec, which `git clone --bare` does not set by default.
- It avoids `git clone --mirror`, which maps remote refs onto local branch refs and conflicts with checked-out worktree branches.
- `wt rm --force` discards uncommitted changes in the selected worktree.
- `wt init` accepts a remote URL or a local checkout path; the source checkout is left untouched.

## Testing

- `tests/path-components.sh` checks `wt` directly against temporary hubs and worktrees. Run it on the host.
- `tests/install-docker.sh` installs `wt` into fresh Ubuntu containers, as root and as a non-root user, then checks the one-liner, `wt init`/`wt new`, completions, and updates. It needs Docker. It installs from the pushed archive (`WT_REF`, default `main`), so push before running it. A run takes about a minute.

Run both after changing `bin/wt` or `install.sh`, and run the Docker test before every push that touches the installer or the install path.

## License

Copyright 2026 Jens Klose. Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE).
