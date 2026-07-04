#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# shellcheck source=../../tool-versions.env
. "$ROOT/tool-versions.env"

install_dir="$HOME/.local/buck2/$BUCK2_RELEASE/bin"
binary_name=buck2
buck2_bin_for_env=""
buck2_arg0_for_env=""
windows=false

case "$(uname -s)" in
  Darwin)
    os=apple-darwin
    ;;
  Linux)
    os=unknown-linux-gnu
    ;;
  MINGW*|MSYS*|CYGWIN*)
    os=pc-windows-msvc
    binary_name=buck2.exe
    windows=true
    ;;
  *)
    printf 'unsupported Buck2 install OS: %s\n' "$(uname -s)" >&2
    exit 1
    ;;
esac

case "$(uname -m)" in
  arm64|aarch64)
    arch=aarch64
    ;;
  x86_64|amd64)
    arch=x86_64
    ;;
  *)
    printf 'unsupported Buck2 install architecture: %s\n' "$(uname -m)" >&2
    exit 1
    ;;
esac

asset="buck2-$arch-$os"
if [[ "$binary_name" == buck2.exe ]]; then
  asset="$asset.exe"
fi

if ! command -v zstd >/dev/null 2>&1; then
  case "$(uname -s)" in
    Darwin)
      brew install zstd
      ;;
    Linux)
      sudo apt-get update
      sudo apt-get install -y zstd
      ;;
    MINGW*|MSYS*|CYGWIN*)
      choco install zstandard -y --no-progress
      export PATH="$PATH:/c/ProgramData/chocolatey/bin"
      ;;
  esac
fi

mkdir -p "$install_dir"

if [[ ! -x "$install_dir/$binary_name" ]]; then
  tmp="$(mktemp -d "${TMPDIR:-/tmp}/buck2-install.XXXXXX")"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL "https://github.com/facebook/buck2/releases/download/$BUCK2_RELEASE/$asset.zst" -o "$tmp/$asset.zst"
  zstd -d -q "$tmp/$asset.zst" -o "$install_dir/$binary_name"
  chmod +x "$install_dir/$binary_name"
fi

if [[ "$windows" == true ]]; then
  buck2_arg0_for_env="$(cygpath -w "$install_dir/$binary_name")"
  buck2_bin_for_env="$install_dir/$binary_name"
else
  buck2_bin_for_env="$install_dir/$binary_name"
  buck2_arg0_for_env="$install_dir/$binary_name"
fi

if [[ -n "${GITHUB_PATH:-}" ]]; then
  printf '%s\n' "$install_dir" >> "$GITHUB_PATH"
else
  printf 'Add %s to PATH to use buck2.\n' "$install_dir"
fi

if [[ -n "${GITHUB_ENV:-}" ]]; then
  printf 'BUCK2_BIN=%s\n' "$buck2_bin_for_env" >> "$GITHUB_ENV"
  printf 'BUCK2_ARG0=%s\n' "$buck2_arg0_for_env" >> "$GITHUB_ENV"
  if [[ "$windows" == true ]]; then
    # Preserve Buck labels such as //crates/... when Git Bash launches native tools.
    printf 'MSYS2_ARG_CONV_EXCL=*\n' >> "$GITHUB_ENV"
  fi
fi

if [[ "$windows" == true ]]; then
  BUCK2_ARG0="$buck2_arg0_for_env" "$buck2_bin_for_env" --version
else
  "$buck2_bin_for_env" --version
fi
