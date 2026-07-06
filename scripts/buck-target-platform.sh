#!/usr/bin/env bash
set -euo pipefail

coverage=false
if [[ "${1:-}" == "--coverage" ]]; then
  coverage=true
fi

rust_host="$(rustc -vV | sed -n 's/^host: //p')"

case "$rust_host" in
  aarch64-apple-darwin)
    platform="//platforms:aarch64-apple-darwin"
    ;;
  x86_64-apple-darwin)
    platform="//platforms:x86_64-apple-darwin"
    ;;
  x86_64-unknown-linux-gnu)
    platform="//platforms:x86_64-unknown-linux-gnu"
    ;;
  x86_64-pc-windows-msvc)
    platform="//platforms:x86_64-pc-windows-msvc"
    ;;
  *)
    printf 'unsupported Rust host for Buck target platform: %s\n' "$rust_host" >&2
    exit 1
    ;;
esac

if [[ "$coverage" == true ]]; then
  case "$platform" in
    //platforms:aarch64-apple-darwin)
      platform="//platforms:aarch64-apple-darwin-coverage"
      ;;
    //platforms:x86_64-apple-darwin)
      platform="//platforms:x86_64-apple-darwin-coverage"
      ;;
    //platforms:x86_64-unknown-linux-gnu)
      platform="//platforms:x86_64-unknown-linux-gnu-coverage"
      ;;
    *)
      printf 'no coverage Buck target platform is defined for %s\n' "$platform" >&2
      exit 1
      ;;
  esac
fi

printf '%s\n' "$platform"
