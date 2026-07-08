#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo-deny >/dev/null 2>&1; then
  echo "cargo-deny is required; run 'just install-cargo-tools'" >&2
  exit 127
fi

cd "${BUILD_WORKSPACE_DIRECTORY:?run this target with 'bazel run'}"

exec cargo deny check licenses bans sources
