#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTH_FILE="$ROOT/.bazelrc.buildbuddy.auth"

metadata_value() {
  printf '%s' "$1" | tr -c '[:alnum:]._-' '_'
}

append_metadata() {
  local key="$1"
  local value="$2"

  if [[ -n "$value" ]]; then
    printf 'build:buildbuddy --build_metadata=%s=%s\n' "$key" "$value"
  fi
}

if [[ -z "${BUILD_BUDDY_API_KEY:-}" ]]; then
  printf 'BUILD_BUDDY_API_KEY is not set; running Bazel without BuildBuddy remote cache.\n'
  exit 0
fi

umask 077
{
  printf 'common:buildbuddy --remote_header=x-buildbuddy-api-key=%s\n' "$BUILD_BUDDY_API_KEY"
  printf 'build:buildbuddy --bes_header=x-buildbuddy-api-key=%s\n' "$BUILD_BUDDY_API_KEY"
  append_metadata ROLE CI
  append_metadata TAG_JOB "$(metadata_value "${GITHUB_JOB:-bazel}")"
  append_metadata TAG_RUNNER_OS "$(metadata_value "${RUNNER_OS:-unknown}")"
  append_metadata TAG_WORKFLOW "$(metadata_value "${GITHUB_WORKFLOW:-unknown}")"
  append_metadata TAG_EVENT "$(metadata_value "${GITHUB_EVENT_NAME:-unknown}")"
  append_metadata TAG_RUN_ID "$(metadata_value "${GITHUB_RUN_ID:-unknown}")"

  if [[ -n "${GITHUB_SERVER_URL:-}" && -n "${GITHUB_REPOSITORY:-}" && -n "${GITHUB_RUN_ID:-}" ]]; then
    append_metadata BUILDBUDDY_LINKS "[GitHub-Actions](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID})"
  fi
} >"$AUTH_FILE"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  bazel_flags="${BAZEL_FLAGS:-}"
  bazel_flags="${bazel_flags:+$bazel_flags }--config=buildbuddy-ci"
  printf 'BAZEL_FLAGS=%s\n' "$bazel_flags" >>"$GITHUB_ENV"
fi

printf 'BuildBuddy remote cache enabled for Bazel commands.\n'
