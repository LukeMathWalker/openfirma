//! Shared integration-test helpers.

use std::{ffi::OsString, path::Path, process::Command};

use fs_err as fs;

/// Run `test` in an isolated process, using a temporary working tree.
///
/// This helper requires process isolation because it mutates process-global
/// state: it clears every `FIRMA_*` environment variable and sets the process
/// cwd. Nextest provides that isolation natively. Other Rust test runners enter
/// a subprocess that runs only the current test.
///
/// The helper creates a temp directory, changes cwd to that temp root,
/// canonicalizes it, and passes the canonical root to `test`. The test body may
/// create additional directories and move cwd again; that remains safe under the
/// nextest process-isolation guard. The temp directory is removed after `test`
/// returns.
pub fn run_isolated(test: impl FnOnce(&Path)) {
    run_isolated_with_env(|_| Vec::new(), test);
}

/// Run `test` in an isolated process with root-derived environment variables.
///
/// This behaves like [`run_isolated`], then calls `env` with the canonical temp
/// root and sets each returned environment variable before running `test`.
/// Existing `FIRMA_*` variables are always cleared before any requested env vars
/// are set.
pub fn run_isolated_with_env(
    env: impl FnOnce(&Path) -> Vec<(OsString, OsString)>,
    test: impl FnOnce(&Path),
) {
    if std::env::var("NEXTEST").as_deref() != Ok("1") {
        let subprocess_result = run_current_test_in_subprocess();
        let error = subprocess_result
            .as_ref()
            .err()
            .map_or("isolated test subprocess failed", String::as_str);
        assert!(subprocess_result.is_ok(), "{error}");
        return;
    }

    clear_firma_env();

    let tmp = tempfile::tempdir().expect("create isolated temporary directory");
    let root = fs::canonicalize(tmp.path()).expect("canonicalize isolated temporary directory");
    std::env::set_current_dir(&root).expect("set cwd to isolated temporary directory");
    set_env_vars(env(&root));

    test(&root);
}

fn run_current_test_in_subprocess() -> Result<(), String> {
    let current_thread = std::thread::current();
    let test_name = current_thread
        .name()
        .ok_or_else(|| "isolated test must run on a named libtest thread".to_string())?;
    let current_exe = std::env::current_exe()
        .map_err(|error| format!("resolve current test binary path: {error}"))?;

    let status = Command::new(current_exe)
        .arg(test_name)
        .arg("--exact")
        .env("NEXTEST", "1")
        .env("RUST_TEST_THREADS", "1")
        .output()
        .map_err(|error| format!("run isolated test subprocess: {error}"))?;

    if status.status.success() {
        Ok(())
    } else {
        let stdout = String::from_utf8_lossy(&status.stdout);
        let stderr = String::from_utf8_lossy(&status.stderr);
        Err(format!(
            "isolated test subprocess failed: {}\nstdout:\n{stdout}\nstderr:\n{stderr}",
            status.status
        ))
    }
}

#[expect(
    unsafe_code,
    reason = "isolated tests run one process per test; env is cleared before test work starts"
)]
/// Clears all `FIRMA_*` environment variables for the current process.
fn clear_firma_env() {
    for (key, _) in std::env::vars_os() {
        let Some(key) = key.as_os_str().to_str() else {
            continue;
        };
        if key.starts_with("FIRMA_") {
            // SAFETY: guarded by `NEXTEST=1`; nextest or this helper executes
            // each isolated test in its own process before the test body.
            unsafe { std::env::remove_var(key) };
        }
    }
}

#[expect(
    unsafe_code,
    reason = "isolated tests run one process per test; env is set before test work starts"
)]
fn set_env_vars(vars: Vec<(OsString, OsString)>) {
    for (key, value) in vars {
        // SAFETY: guarded by `NEXTEST=1`; nextest or this helper executes each
        // isolated test in its own process before invoking the test body.
        unsafe { std::env::set_var(key, value) };
    }
}
