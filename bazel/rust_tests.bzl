load("@crates//:defs.bzl", "aliases", "all_crate_deps", "crate_edition")
load("@rules_rust//rust:defs.bzl", "rust_test")

def cargo_integration_test(name, src, deps = [], data = [], args = [], env = {}, rustc_env = {}):
    rust_test(
        name = name,
        srcs = [src] + native.glob(["tests/support/**/*.rs"], allow_empty = True),
        aliases = aliases(
            normal = True,
            normal_dev = True,
            proc_macro = True,
            proc_macro_dev = True,
        ),
        args = args,
        crate_name = name,
        crate_root = src,
        data = data,
        deps = all_crate_deps(normal = True) + all_crate_deps(normal_dev = True) + deps,
        edition = crate_edition(),
        env = env,
        proc_macro_deps = all_crate_deps(proc_macro = True) + all_crate_deps(proc_macro_dev = True),
        rustc_env = rustc_env,
    )
