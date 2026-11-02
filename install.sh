#!/usr/bin/env bash
# Install wt: download the repository snapshot, link bin/wt into PATH.
#   curl -fsSL https://raw.githubusercontent.com/mazehall/wt/main/install.sh | bash
# Env: GITHUB_TOKEN (only while the repository is private), WT_REF (default main),
#      WT_HOME (default ~/.local/share/wt). Rerun to update.
set -euo pipefail

repo="mazehall/wt"
ref="${WT_REF:-main}"
home="${WT_HOME:-$HOME/.local/share/wt}"

die() { echo "install: $*" >&2; exit 1; }
command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
command -v git >/dev/null 2>&1 || die "wt needs git; install it and rerun"

fetch() { # url dest
  if [ -n "${GITHUB_TOKEN:-}" ]; then
    curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -o "$2" "$1"
  else
    curl -fsSL -o "$2" "$1"
  fi
}

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
fetch "https://api.github.com/repos/$repo/tarball/$ref" "$tmp/src.tgz" ||
  die "download failed (private repository? set GITHUB_TOKEN)"
mkdir "$tmp/src"
tar -xzf "$tmp/src.tgz" -C "$tmp/src" --strip-components=1
[ -f "$tmp/src/bin/wt" ] || die "archive has no bin/wt"

rm -rf "$home"
mkdir -p "$(dirname "$home")"
mv "$tmp/src" "$home"
target="$home/bin/wt"
chmod 755 "$target"
echo "install: fetched $repo@$ref into $home"

# Replace an existing wt symlink in place; otherwise use the first writable
# directory already on PATH, in order of preference.
bindir=""
existing="$(command -v wt || true)"
if [ -n "$existing" ] && [ -L "$existing" ]; then
  bindir="$(dirname "$existing")"
else
  for d in "$HOME/.local/bin" "$HOME/bin" /opt/homebrew/bin /usr/local/bin; do
    case ":$PATH:" in *":$d:"*) ;; *) continue ;; esac
    if [ -d "$d" ] && [ -w "$d" ]; then bindir="$d"; break; fi
  done
fi
if [ -z "$bindir" ]; then
  bindir="$HOME/.local/bin"
  mkdir -p "$bindir"
  echo "install: $bindir is not on PATH; add it to your shell profile:" >&2
  echo "  export PATH=\"$bindir:\$PATH\"" >&2
fi

dest="$bindir/wt"
if [ -e "$dest" ] && [ ! -L "$dest" ]; then
  die "$dest exists and is not a symlink; remove it or edit PATH"
fi
ln -sfn "$target" "$dest"
echo "install: $dest -> $target"

resolved="$(command -v wt || true)"
if [ "$resolved" != "$dest" ]; then
  echo "warning: 'wt' on PATH resolves to ${resolved:-nothing}, not $dest" >&2
fi
