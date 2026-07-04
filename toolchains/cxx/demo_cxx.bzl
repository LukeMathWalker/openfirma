load("@prelude//toolchains:cxx.bzl", "system_cxx_toolchain")

def system_demo_cxx_toolchain():
    system_cxx_toolchain(
        name = "cxx",
        compiler = select({
            "prelude//os/constraints:linux": "/usr/bin/clang",
            "prelude//os/constraints:macos": "/usr/bin/clang",
            "prelude//os/constraints:windows": "cl.exe",
            "DEFAULT": "/usr/bin/cc",
        }),
        cxx_compiler = select({
            "prelude//os/constraints:linux": "/usr/bin/clang++",
            "prelude//os/constraints:macos": "/usr/bin/clang++",
            "prelude//os/constraints:windows": "cl.exe",
            "DEFAULT": "/usr/bin/c++",
        }),
        linker = select({
            "prelude//os/constraints:linux": "/usr/bin/clang++",
            "prelude//os/constraints:macos": "/usr/bin/clang++",
            "prelude//os/constraints:windows": "link.exe",
            "DEFAULT": "/usr/bin/c++",
        }),
        archiver = select({
            "prelude//os/constraints:linux": "/usr/bin/ar",
            "prelude//os/constraints:macos": "/usr/bin/ar",
            "prelude//os/constraints:windows": "lib.exe",
            "DEFAULT": "/usr/bin/ar",
        }),
        c_flags = select({
            "prelude//cpu/constraints:arm64": ["-arch", "arm64"],
            "DEFAULT": [],
        }),
        cxx_flags = select({
            "prelude//cpu/constraints:arm64": ["-arch", "arm64"],
            "DEFAULT": [],
        }),
        link_flags = select({
            "prelude//os/constraints:linux": ["-fuse-ld=bfd"],
            "prelude//cpu/constraints:arm64": ["-arch", "arm64"],
            "DEFAULT": [],
        }),
        visibility = ["PUBLIC"],
    )
