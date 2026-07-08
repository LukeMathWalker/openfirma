load("@crates//:defs.bzl", "aliases", "all_crate_deps")
load("@rules_rs//rs:rust_test.bzl", "rust_test")

def cargo_integration_test(name, src, deps = [], data = [], args = [], env = {}, rustc_env = {}):
    rust_test(
        name = name,
        srcs = [src] + native.glob(["tests/support/**/*.rs"], allow_empty = True),
        aliases = aliases(),
        args = args,
        crate_name = name,
        crate_root = src,
        data = data,
        deps = all_crate_deps(normal = True, normal_dev = True) + deps,
        edition = "2024",
        env = env,
        rustc_env = rustc_env,
    )
