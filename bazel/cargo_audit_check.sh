#!/usr/bin/env bash
set -euo pipefail

if ! command -v cargo-audit >/dev/null 2>&1; then
  echo "cargo-audit is required; run 'just install-cargo-tools'" >&2
  exit 127
fi

cd "${BUILD_WORKSPACE_DIRECTORY:?run this target with 'bazel run'}"

exec cargo audit --deny warnings
