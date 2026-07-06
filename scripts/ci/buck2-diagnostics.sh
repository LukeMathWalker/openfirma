#!/usr/bin/env bash
set +e

label="${1:-most recent Buck2 invocation}"
buck2_bin="${BUCK2_BIN:-buck2}"

printf 'Showing Buck2 diagnostics after: %s\n' "$label"

if ! command -v "$buck2_bin" >/dev/null 2>&1; then
  printf 'buck2 binary not found: %s\n' "$buck2_bin" >&2
  exit 0
fi

"$buck2_bin" log summary --recent 0 || true
"$buck2_bin" log what-uploaded --recent 0 || true

if command -v rg >/dev/null 2>&1; then
  "$buck2_bin" log show --recent 0 | rg -i 're_|remote|cache|upload|download|action_cache|cas' || true
else
  printf 'ripgrep is not available; skipping filtered Buck2 event log output.\n'
fi

exit 0
