set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

bazel_flags := env_var_or_default("BAZEL_FLAGS", "")
bazel_startup_flags := env_var_or_default("BAZEL_STARTUP_FLAGS", "")

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
  cargo clippy --all-features --all-targets -- -D warnings

test:
  cargo nextest run --all-features --all-targets --no-fail-fast
  # nextest runs unit + integration tests; it does not run doctests, so those
  # run separately via `cargo test --doc`.
  cargo test --all-features --doc

build:
  cargo build --all-features --all-targets

bazel-build:
  bazel {{bazel_startup_flags}} query {{bazel_flags}} 'kind("rust_(library|binary) rule", //...) except tests(//...)' | \
    xargs bazel {{bazel_startup_flags}} build {{bazel_flags}}

bazel-test:
  bazel {{bazel_startup_flags}} test {{bazel_flags}} //...

bazel-lint:
  bazel {{bazel_startup_flags}} build {{bazel_flags}} //... --aspects=@rules_rust//rust:defs.bzl%rust_clippy_aspect --output_groups=clippy_checks --@rules_rust//rust/settings:clippy_flags=-Dwarnings

bazel-rustfmt:
  bazel {{bazel_startup_flags}} build {{bazel_flags}} //... --aspects=@rules_rust//rust:defs.bzl%rustfmt_aspect --output_groups=rustfmt_checks

bazel-audit:
  bazel {{bazel_startup_flags}} run {{bazel_flags}} //bazel:cargo_audit_check

bazel-deny:
  bazel {{bazel_startup_flags}} run {{bazel_flags}} //bazel:cargo_deny_check

bazel-check: bazel-build bazel-test bazel-lint bazel-rustfmt bazel-audit bazel-deny

e2e:
  cargo nextest run -p firma --test e2e --run-ignored all

audit:
  cargo audit --deny warnings

deny:
  cargo deny check licenses bans sources

check: fmt lint test build audit deny

coverage:
  cargo llvm-cov nextest --workspace --all-features --codecov --output-path codecov.json

bazel-coverage:
  bazel {{bazel_startup_flags}} coverage {{bazel_flags}} //... --combined_report=lcov --instrumentation_filter='^//crates[/:]'
  cp "$(bazel {{bazel_startup_flags}} info {{bazel_flags}} output_path)/_coverage/_coverage_report.dat" bazel-coverage.lcov

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
