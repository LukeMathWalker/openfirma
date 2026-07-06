load("@prelude//toolchains:rust.bzl", "system_rust_toolchain")

def system_demo_rust_toolchain():
    system_rust_toolchain(
        name = "rust",
        rustc_target_triple = select({
            "prelude//os/constraints:linux": "x86_64-unknown-linux-gnu",
            "root//platforms:macos-arm64": "aarch64-apple-darwin",
            "root//platforms:macos-x86_64": "x86_64-apple-darwin",
            "prelude//os/constraints:windows": "x86_64-pc-windows-msvc",
            "DEFAULT": "x86_64-unknown-linux-gnu",
        }),
        default_edition = "2024",
        rustc_flags = select({
            "root//platforms:rust-coverage-enabled-setting": ["-Cinstrument-coverage"],
            "DEFAULT": [],
        }),
        visibility = ["PUBLIC"],
    )
