use std::path::PathBuf;

#[must_use]
pub fn firma_bin() -> PathBuf {
    resolve_runfile(env!("CARGO_BIN_EXE_firma"))
}

fn resolve_runfile(path: &str) -> PathBuf {
    let direct = PathBuf::from(path);
    if direct.is_absolute() {
        return direct;
    }
    if direct.exists() {
        let cwd = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
        return cwd.join(direct);
    }

    bazel_runfile(path).unwrap_or(direct)
}

fn bazel_runfile(logical_path: &str) -> Option<PathBuf> {
    let candidates = [
        logical_path.to_string(),
        format!("_main/{logical_path}"),
        format!("openfirma/{logical_path}"),
    ];

    if let Some(runfiles_dir) = std::env::var_os("RUNFILES_DIR") {
        let runfiles_dir = PathBuf::from(runfiles_dir);
        for candidate in &candidates {
            let path = runfiles_dir.join(candidate);
            if path.exists() {
                return Some(path);
            }
        }
    }

    let manifest = std::env::var("RUNFILES_MANIFEST_FILE").ok()?;
    let manifest = std::fs::read_to_string(manifest).ok()?;
    for line in manifest.lines() {
        let Some((key, value)) = line.split_once(' ') else {
            continue;
        };
        if candidates.iter().any(|candidate| candidate == key) {
            return Some(PathBuf::from(value));
        }
    }
    None
}
