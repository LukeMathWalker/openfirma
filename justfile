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
  targets=( \
    '//crates/firma-core:firma_core[clippy.txt]' \
    '//crates/firma-runtime-state:firma_runtime_state[clippy.txt]' \
    '//crates/firma-config-loader:firma_config_loader[clippy.txt]' \
    '//crates/firma-config-loader:firma_config_loader_clap[clippy.txt]' \
    '//crates/firma-stack:firma_stack[clippy.txt]' \
    '//crates/firma-demo-fixture:firma_demo_fixture_lib[clippy.txt]' \
    '//crates/firma-demo-fixture:firma-demo-fixture[clippy.txt]' \
    '//crates/firma-demo-fixture:firma-demo-fixture-client[clippy.txt]' \
    '//crates/firma-protobuf:firma_protobuf[clippy.txt]' \
    '//crates/firma-protobuf:firma-protobuf-build-script-build[clippy.txt]' \
    '//crates/firma-grpc-interceptor-proto:firma_grpc_interceptor_proto[clippy.txt]' \
    '//crates/firma-grpc-interceptor-proto:firma-grpc-interceptor-proto-build-script-build[clippy.txt]' \
    '//crates/firma-authority:firma_authority[clippy.txt]' \
    '//crates/firma-sidecar:firma_sidecar[clippy.txt]' \
    '//crates/firma-run:firma_run[clippy.txt]' \
    '//crates/firma-demo-tui:firma-demo-tui[clippy.txt]' \
    '//crates/firma-vz-runner:firma-vz-runner[clippy.txt]' \
    '//crates/firma:firma[clippy.txt]' \
  ); \
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
  cargo nextest run --all-features --all-targets --no-fail-fast
  # nextest runs unit + integration tests; it does not run doctests, so those
  # run separately via `cargo test --doc`.
  cargo test --all-features --doc

build:
  buck2 build --target-platforms //platforms:aarch64-apple-darwin \
    //crates/firma-core:firma_core \
    //crates/firma-runtime-state:firma_runtime_state \
    //crates/firma-config-loader:firma_config_loader \
    //crates/firma-stack:firma_stack \
    //crates/firma-demo-fixture:firma_demo_fixture_lib \
    //crates/firma-demo-fixture:firma-demo-fixture \
    //crates/firma-demo-fixture:firma-demo-fixture-client \
    //crates/firma-protobuf:firma_protobuf \
    //crates/firma-grpc-interceptor-proto:firma_grpc_interceptor_proto \
    //crates/firma-authority:firma_authority \
    //crates/firma-sidecar:firma_sidecar \
    //crates/firma-run:firma_run \
    //crates/firma-demo-tui:firma-demo-tui \
    //crates/firma-vz-runner:firma-vz-runner \
    //crates/firma:firma

e2e:
  cargo nextest run -p firma --test e2e --run-ignored all

audit:
  cargo audit --deny warnings

deny:
  cargo deny check licenses bans sources

check: fmt lint test build audit deny

coverage:
  cargo llvm-cov nextest --workspace --all-features --codecov --output-path codecov.json

fuzz-check:
  nightly="$(< .rust-nightly)"
  cd fuzz && cargo +"$nightly" check

bench:
  cargo bench --workspace --no-fail-fast

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
