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
  buck2 test --target-platforms //platforms:aarch64-apple-darwin \
    //crates/firma-core:unit_tests \
    //crates/firma-runtime-state:unit_tests \
    //crates/firma-runtime-state:process_id_test \
    //crates/firma-runtime-state:pidfile_roundtrip_test \
    //crates/firma-runtime-state:runtime_paths_test \
    //crates/firma-runtime-state:sidecar_markers_test \
    //crates/firma-runtime-state:state_dir_resolution_test \
    //crates/firma-config-loader:unit_tests \
    //crates/firma-config-loader:integration_test \
    //crates/firma-stack:unit_tests \
    //crates/firma-stack:config_parse_test \
    //crates/firma-stack:status_state_machine_test \
    //crates/firma-authority:unit_tests \
    //crates/firma-authority:profile_developer_test \
    //crates/firma-authority:e2e_test \
    //crates/firma-authority:e2e_mtls_test \
    //crates/firma-sidecar:unit_tests \
    //crates/firma-run:unit_tests \
    //crates/firma-run:authority_bootstrap_prompt_test \
    //crates/firma-run:authority_autostart_eaddrinuse_test \
    //crates/firma-run:authority_autostart_reuse_test \
    //crates/firma-run:authority_autostart_kill_on_drop_test \
    //crates/firma-run:authority_autostart_timeout_test \
    //crates/firma-run:authority_autostart_marker_test \
    //crates/firma-run:sidecar_autostart_kill_on_drop_test \
    //crates/firma-run:sidecar_autostart_timeout_test \
    //crates/firma-run:sidecar_autostart_env_sandbox_id_test \
    //crates/firma-run:sidecar_config_merge_test \
    //crates/firma-run:authority_autostart_ready_scrape_test \
    //crates/firma-run:sidecar_autostart_ready_scrape_test \
    //crates/firma-vz-runner:unit_tests \
    //crates/firma:unit_tests \
    //crates/firma:cli_help_test \
    //crates/firma:cli_parsing_test \
    //crates/firma:run_authority_flags_test \
    //crates/firma:run_autostart_flags_test \
    //crates/firma:monitor_decoupled_test \
    //crates/firma:monitor_audit_stream_test \
    //crates/firma:authority_keygen_test \
    //crates/firma:doctor_test \
    //crates/firma:run_echo_smoke_test \
    //crates/firma:sidecar_status_cli_test \
    //crates/firma:stack_teardown_grandchildren_test \
    //crates/firma:run_implicit_init_prompt_test \
    //crates/firma:stack_lifecycle_test \
    //crates/firma:sidecar_invalid_config_test \
    //crates/firma:firma_config_test \
    //crates/firma:policy_cli_test \
    //crates/firma:sidecar_startup_contract_test \
    //crates/firma:sidecar_tampered_seed_e2e_test \
    //crates/firma:seeded_capability_e2e_test \
    //crates/firma:sidecar_readiness_gate_test \
    //crates/firma:e2e_startup_test \
    //crates/firma:live_capability_e2e_test \
    //crates/firma:child_process_escape_test
  # Buck2 runs unit + integration tests; it does not run doctests, so those
  # run separately via Cargo until a Buck rustdoc-test target exists.
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
  buck2 run --target-platforms //platforms:aarch64-apple-darwin //tests/e2e:main_test -- --include-ignored

audit:
  cargo audit --file third-party/Cargo.lock --deny warnings

deny:
  cargo deny --manifest-path third-party/Cargo.toml --locked check licenses bans sources

check: fmt lint test build audit deny

coverage:
  targets=( \
    //crates/firma-core:unit_tests \
    //crates/firma-runtime-state:unit_tests \
    //crates/firma-runtime-state:process_id_test \
    //crates/firma-runtime-state:pidfile_roundtrip_test \
    //crates/firma-runtime-state:runtime_paths_test \
    //crates/firma-runtime-state:sidecar_markers_test \
    //crates/firma-runtime-state:state_dir_resolution_test \
    //crates/firma-config-loader:unit_tests \
    //crates/firma-config-loader:integration_test \
    //crates/firma-stack:unit_tests \
    //crates/firma-stack:config_parse_test \
    //crates/firma-stack:status_state_machine_test \
    //crates/firma-authority:unit_tests \
    //crates/firma-authority:profile_developer_test \
    //crates/firma-authority:e2e_test \
    //crates/firma-authority:e2e_mtls_test \
    //crates/firma-sidecar:unit_tests \
    //crates/firma-run:unit_tests \
    //crates/firma-run:authority_bootstrap_prompt_test \
    //crates/firma-run:authority_autostart_eaddrinuse_test \
    //crates/firma-run:authority_autostart_reuse_test \
    //crates/firma-run:authority_autostart_kill_on_drop_test \
    //crates/firma-run:authority_autostart_timeout_test \
    //crates/firma-run:authority_autostart_marker_test \
    //crates/firma-run:sidecar_autostart_kill_on_drop_test \
    //crates/firma-run:sidecar_autostart_timeout_test \
    //crates/firma-run:sidecar_autostart_env_sandbox_id_test \
    //crates/firma-run:sidecar_config_merge_test \
    //crates/firma-run:authority_autostart_ready_scrape_test \
    //crates/firma-run:sidecar_autostart_ready_scrape_test \
    //crates/firma-vz-runner:unit_tests \
    //crates/firma:unit_tests \
    //crates/firma:cli_help_test \
    //crates/firma:cli_parsing_test \
    //crates/firma:run_authority_flags_test \
    //crates/firma:run_autostart_flags_test \
    //crates/firma:monitor_decoupled_test \
    //crates/firma:monitor_audit_stream_test \
    //crates/firma:authority_keygen_test \
    //crates/firma:doctor_test \
    //crates/firma:run_echo_smoke_test \
    //crates/firma:sidecar_status_cli_test \
    //crates/firma:stack_teardown_grandchildren_test \
    //crates/firma:run_implicit_init_prompt_test \
    //crates/firma:stack_lifecycle_test \
    //crates/firma:sidecar_invalid_config_test \
    //crates/firma:firma_config_test \
    //crates/firma:policy_cli_test \
    //crates/firma:sidecar_startup_contract_test \
    //crates/firma:sidecar_tampered_seed_e2e_test \
    //crates/firma:seeded_capability_e2e_test \
    //crates/firma:sidecar_readiness_gate_test \
    //crates/firma:e2e_startup_test \
    //crates/firma:live_capability_e2e_test \
    //crates/firma:child_process_escape_test \
  ); \
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
