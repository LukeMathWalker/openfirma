#!/usr/bin/env bash
set -euo pipefail

: "${RUNNER_TEMP:?RUNNER_TEMP is required}"
: "${GITHUB_ENV:?GITHUB_ENV is required}"

runner_temp="$RUNNER_TEMP"
if [[ "${RUNNER_OS:-}" == 'Windows' ]]; then
  runner_temp="$(cygpath -u "$runner_temp")"
fi

repository_cache="$runner_temp/bazel-repository-cache"

mkdir -p "$repository_cache"

bazel_flags="${BAZEL_FLAGS:-}"
bazel_flags="${bazel_flags:+$bazel_flags }--repository_cache=$repository_cache"

{
  printf 'BAZEL_REPOSITORY_CACHE=%s\n' "$repository_cache"
  printf 'BAZEL_FLAGS=%s\n' "$bazel_flags"
} >>"$GITHUB_ENV"

printf 'Bazel repository cache enabled at %s\n' "$repository_cache"
