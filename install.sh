#!/usr/bin/env bash
# Link bin/wt from this checkout into a directory on PATH.
# Usage: install.sh   (set WT_NO_UPDATE=1 to skip git pull)
set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
target="$src/bin/wt"
[ -x "$target" ] || { echo "install: $target missing or not executable" >&2; exit 1; }

if [ -d "$src/.git" ] && [ -z "${WT_NO_UPDATE:-}" ]; then
  git -C "$src" pull --ff-only --quiet ||
    echo "install: git pull failed; linking the current checkout as is" >&2
fi

# First writable directory that is already on PATH, in order of preference.
bindir=""
for d in "$HOME/.local/bin" "$HOME/bin" /opt/homebrew/bin /usr/local/bin; do
  case ":$PATH:" in *":$d:"*) ;; *) continue ;; esac
  if [ -d "$d" ] && [ -w "$d" ]; then bindir="$d"; break; fi
done
if [ -z "$bindir" ]; then
  bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  echo "install: $bindir is not on PATH; add it to your shell profile:" >&2
  echo "  export PATH=\"$bindir:\$PATH\"" >&2
fi

dest="$bindir/wt"
if [ -e "$dest" ] && [ ! -L "$dest" ]; then
  echo "install: $dest exists and is not a symlink; remove it or edit PATH" >&2
  exit 1
fi
ln -sfn "$target" "$dest"
echo "install: $dest -> $target"

resolved="$(command -v wt || true)"
if [ "$resolved" != "$dest" ]; then
  echo "warning: 'wt' on PATH resolves to ${resolved:-nothing}, not $dest" >&2
fi
