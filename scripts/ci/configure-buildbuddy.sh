#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTH_FILE="$ROOT/.bazelrc.buildbuddy.auth"

if [[ -z "${BUILD_BUDDY_API_KEY:-}" ]]; then
  printf 'BUILD_BUDDY_API_KEY is not set; running Bazel without BuildBuddy remote cache.\n'
  exit 0
fi

umask 077
printf 'common:buildbuddy --remote_header=x-buildbuddy-api-key=%s\n' "$BUILD_BUDDY_API_KEY" >"$AUTH_FILE"
printf 'BAZEL_FLAGS=--config=buildbuddy\n' >>"${GITHUB_ENV:?GITHUB_ENV must be set in CI}"
printf 'BuildBuddy remote cache enabled for Bazel commands.\n'
