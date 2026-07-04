set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

install: install-system install-cargo-tools install-docs-deps install-tools
  @echo "Dev environment ready. Try 'just check' or 'just docs-dev'."

install-system:
  ./scripts/dev/install-system.sh

install-tools:
  if ! command -v trufflehog >/dev/null 2>&1; then \
    echo "warning: trufflehog not found - install from https://github.com/trufflesecurity/trufflehog/releases"; \
    echo "         (macOS: brew install trufflehog)"; \
  fi
  git config core.hooksPath .githooks
  echo "Git hooks wired to .githooks/"

install-cargo-tools:
  ./scripts/dev/install-cargo-tools.sh

install-docs-deps:
  cd docs-site && corepack pnpm install --frozen-lockfile --registry=https://registry.npmjs.org/

fmt:
  dprint check

lint:
  targets=(); \
  while read -r target; do \
    targets+=("$target[clippy.txt]"); \
  done < <(buck2 uquery 'kind("rust_(binary|library|proc_macro)", //crates/...)'); \
  outputs=(); \
  while read -r target output; do \
    [[ "$target" == root//* ]] || continue; \
    outputs+=("$output"); \
  done < <(buck2 build --show-output --target-platforms //platforms:aarch64-apple-darwin "${targets[@]}"); \
  failed=0; \
  for output in "${outputs[@]}"; do \
    if [[ -s "$output" ]]; then \
      printf '\n%s\n' "$output"; \
      printf '%0.s-' {1..80}; \
      printf '\n'; \
      cat "$output"; \
      failed=1; \
    fi; \
  done; \
  if [[ "$failed" -ne 0 ]]; then \
    exit 1; \
  fi

test:
  mapfile -t test_targets < <(buck2 uquery 'kind("rust_test", //crates/...)'); \
  buck2 test --target-platforms //platforms:aarch64-apple-darwin "${test_targets[@]}"
  # The Buck Rust prelude exposes doctests through each library's [doc]
  # subtarget. Keep them separate from unit and
  # integration tests, matching the old cargo-nextest + cargo-doc split.
  doc_targets=(); \
  while read -r target; do \
    doc_targets+=("$target[doc]"); \
  done < <(buck2 uquery 'kind("rust_library", //crates/...)'); \
  buck2 test --target-platforms //platforms:aarch64-apple-darwin "${doc_targets[@]}"

build:
  mapfile -t targets < <(buck2 uquery 'kind("rust_(binary|library|proc_macro)", //crates/...)'); \
  buck2 build --target-platforms //platforms:aarch64-apple-darwin "${targets[@]}"

e2e:
  buck2 run --target-platforms //platforms:aarch64-apple-darwin //tests/e2e:main_test -- --include-ignored

audit:
  cargo audit --file third-party/Cargo.lock --deny warnings

deny:
  cargo deny --manifest-path third-party/Cargo.toml --locked check licenses bans sources

check: fmt lint test build audit deny

coverage:
  mapfile -t targets < <(buck2 uquery 'kind("rust_test", //crates/...)'); \
  llvm_profdata="${LLVM_PROFDATA:-}"; \
  if [[ -z "$llvm_profdata" ]]; then llvm_profdata="$(command -v llvm-profdata || true)"; fi; \
  if [[ -z "$llvm_profdata" ]] && command -v xcrun >/dev/null 2>&1; then llvm_profdata="$(xcrun --find llvm-profdata)"; fi; \
  if [[ -z "$llvm_profdata" ]]; then printf 'llvm-profdata not found; set LLVM_PROFDATA\n' >&2; exit 1; fi; \
  llvm_cov="${LLVM_COV:-}"; \
  if [[ -z "$llvm_cov" ]]; then llvm_cov="$(command -v llvm-cov || true)"; fi; \
  if [[ -z "$llvm_cov" ]] && command -v xcrun >/dev/null 2>&1; then llvm_cov="$(xcrun --find llvm-cov)"; fi; \
  if [[ -z "$llvm_cov" ]]; then printf 'llvm-cov not found; set LLVM_COV\n' >&2; exit 1; fi; \
  coverage_dir=target/buck-coverage; \
  profile_dir="$(mktemp -d "${TMPDIR:-/tmp}/openfirma-coverage.XXXXXX")"; \
  trap 'rm -rf "$profile_dir"' EXIT; \
  rm -rf "$coverage_dir"; \
  mkdir -p "$coverage_dir"; \
  objects=(); \
  while read -r target output; do \
    [[ "$target" == root//* ]] || continue; \
    objects+=("$output"); \
  done < <(buck2 build --show-output --target-platforms //platforms:aarch64-apple-darwin-coverage "${targets[@]}"); \
  buck2 test --target-platforms //platforms:aarch64-apple-darwin-coverage "${targets[@]}" -- --env LLVM_PROFILE_FILE="$profile_dir/%m-%p.profraw"; \
  shopt -s nullglob; \
  profiles=("$profile_dir"/*.profraw); \
  if [[ "${#profiles[@]}" -eq 0 ]]; then printf 'no coverage profiles were produced\n' >&2; exit 1; fi; \
  "$llvm_profdata" merge -sparse "${profiles[@]}" -o "$coverage_dir/codecov.profdata"; \
  llvm_cov_args=(export --format=lcov --instr-profile="$coverage_dir/codecov.profdata" --ignore-filename-regex='(^/.*\.rustup/|^buck-out/|^third-party/|/\.cargo/registry/)'); \
  for object in "${objects[@]}"; do llvm_cov_args+=(--object "$object"); done; \
  "$llvm_cov" "${llvm_cov_args[@]}" > "$coverage_dir/lcov.info"; \
  printf 'Coverage written to %s\n' "$coverage_dir/lcov.info"

fuzz-check:
  buck2 build --target-platforms //platforms:aarch64-apple-darwin \
    '//fuzz:normalizer[check]' \
    '//fuzz:paseto_verify[check]' \
    '//fuzz:capability_seed[check]' \
    '//fuzz:capability_seed_toml[check]'

bench:
  targets=( \
    //crates/firma-core:paseto_bench \
    //crates/firma-sidecar:revocation_bench \
    //crates/firma-sidecar:cedar_eval_bench \
    //crates/firma-sidecar:bundle_reload_bench \
    //crates/firma-sidecar:stage1_bench \
    //crates/firma-sidecar:pipeline_bench \
  ); \
  failed=0; \
  for target in "${targets[@]}"; do \
    buck2 run --target-platforms //platforms:aarch64-apple-darwin "$target" || failed=1; \
  done; \
  exit "$failed"

docs-build:
  cd docs-site && corepack pnpm install --frozen-lockfile --registry=https://registry.npmjs.org/
  cd docs-site && ASTRO_TELEMETRY_DISABLED=1 corepack pnpm run build:with-rustdoc

docs: docs-build
  cd docs-site && ASTRO_TELEMETRY_DISABLED=1 corepack pnpm exec astro preview --host 127.0.0.1 --open

docs-dev:
  cd docs-site && corepack pnpm install --frozen-lockfile --registry=https://registry.npmjs.org/
  cd docs-site && corepack pnpm run build:rustdoc-mdx
  cd docs-site && ASTRO_TELEMETRY_DISABLED=1 corepack pnpm dev --host 127.0.0.1 --open

demo:
  ./examples/demo/run.sh hero

demo-repl:
  ./examples/demo/run.sh repl

demo-ci:
  ./examples/demo/run.sh ci

managed-seccomp-compat-check:
  ./scripts/seccomp/check-managed-compatibility.sh
