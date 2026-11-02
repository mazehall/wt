#!/usr/bin/env bash
# Install test in a throwaway Ubuntu container. Installs from the GitHub archive
# of WT_REF (default main), so push first. Needs docker.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd -P)"
repo_root="$(cd "$here/.." && pwd -P)"
image="${WT_TEST_IMAGE:-ubuntu:24.04}"

docker run --rm \
  -v "$repo_root/install.sh:/repo/install.sh:ro" \
  -v "$here/install-check.sh:/check.sh:ro" \
  "$image" bash -c 'apt-get update -qq >/dev/null &&
    apt-get install -y -qq curl ca-certificates git tar >/dev/null 2>&1 &&
    bash /check.sh'
