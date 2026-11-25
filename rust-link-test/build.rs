// Links libSwiftFmtShim.a into a plain Rust binary and wires up the Swift
// runtime on the consumer side. All configuration comes from env vars that
// the GitHub Actions workflow sets, so link-flag variants can be iterated on
// purely from CI without touching this file.
//
//   SWIFTFMT_MODE            linux-static | linux-dynamic | macos-system
//   SWIFTFMT_STATIC_A        path to libSwiftFmtShim.a (required)
//   SWIFTFMT_SWIFT_USRLIB    Swift toolchain's usr/lib dir (required on Linux)
//   SWIFTFMT_EXTRA_LIBS      extra space-separated -l names appended last
//   SWIFTFMT_EXTRA_FRAMEWORKS  extra space-separated macOS -framework names
//   SWIFTFMT_EXTRA_LINK_ARGS   extra space-separated raw link args
use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    for k in [
        "SWIFTFMT_MODE",
        "SWIFTFMT_STATIC_A",
        "SWIFTFMT_SWIFT_USRLIB",
        "SWIFTFMT_EXTRA_LIBS",
        "SWIFTFMT_EXTRA_FRAMEWORKS",
        "SWIFTFMT_EXTRA_LINK_ARGS",
    ] {
        println!("cargo:rerun-if-env-changed={k}");
    }

    let mode = env::var("SWIFTFMT_MODE").unwrap_or_else(|_| "linux-static".to_string());
    let static_a = env::var("SWIFTFMT_STATIC_A")
        .unwrap_or_else(|_| panic!("SWIFTFMT_STATIC_A must point to libSwiftFmtShim.a"));
    let static_a = PathBuf::from(&static_a);
    assert!(
        static_a.exists(),
        "static archive not found: {}",
        static_a.display()
    );
    let lib_dir = static_a.parent().unwrap();
    println!("cargo:rustc-link-search=native={}", lib_dir.display());
    println!("cargo:rustc-link-lib=static=SwiftFmtShim");

    let usrlib = env::var("SWIFTFMT_SWIFT_USRLIB");

    match mode.as_str() {
        "linux-static" => {
            // The key experiment: link the Swift runtime STATICALLY from the
            // toolchain's swift_static/linux archive set on the Rust side.
            let u = usrlib.expect("SWIFTFMT_SWIFT_USRLIB required for linux-static");
            let static_dir = Path::new(&u).join("swift_static/linux");
            println!("cargo:rustc-link-search=native={}", static_dir.display());

            // Link every static archive the toolchain ships. Archive members
            // are only pulled in when actually referenced, so this is both
            // robust across toolchain versions and dependency-order-proof.
            let mut names: Vec<String> = Vec::new();
            for e in fs::read_dir(&static_dir)
                .unwrap_or_else(|e| panic!("cannot list {}: {e}", static_dir.display()))
            {
                let e = e.unwrap();
                let n = e.file_name().to_string_lossy().to_string();
                if let Some(stem) = n.strip_prefix("lib").and_then(|s| s.strip_suffix(".a")) {
                    names.push(stem.to_string());
                }
            }
            // Rough dependency order: swiftCore first, then the rest.
            names.sort_by_key(|n| match n.as_str() {
                "swiftCore" => 0,
                "swiftSwiftOnoneSupport" => 1,
                _ => 2,
            });
            for n in &names {
                println!("cargo:rustc-link-lib=static={n}");
            }

            // swiftCore is C++: provide the C++ runtime. libstdc++ is the
            // default guess; if the toolchain's swiftCore was built against
            // libc++ the workflow sets SWIFTFMT_EXTRA_LIBS="c++" instead
            // (the extra lib links after this one and wins symbol resolution).
            println!("cargo:rustc-link-lib=stdc++");
            // rpath so the binary also finds a toolchain-shipped libc++.so.1
            // at run time on the build host. Production builds would bundle
            // or statically link the C++ runtime instead.
            println!("cargo:rustc-link-arg=-Wl,-rpath,{u}");
        }
        "linux-dynamic" => {
            // Reference experiment: consumer relies on the toolchain's shared
            // Swift runtime (swift/linux/*.so) via -L/-l + rpath.
            let u = usrlib.expect("SWIFTFMT_SWIFT_USRLIB required for linux-dynamic");
            let dyn_dir = Path::new(&u).join("swift/linux");
            println!("cargo:rustc-link-search=native={}", dyn_dir.display());
            println!("cargo:rustc-link-arg=-Wl,-rpath,{}", dyn_dir.display());
            for l in [
                "swiftCore",
                "swiftSwiftOnoneSupport",
                "swift_StringProcessing",
                "swift_Concurrency",
                "swiftGlibc",
                "swiftFoundation",
                "swiftFoundationICU",
                "dispatch",
                "BlocksRuntime",
            ] {
                if dyn_dir.join(format!("lib{l}.so")).exists() {
                    println!("cargo:rustc-link-lib=dylib={l}");
                }
            }
        }
        "macos-system" => {
            // macOS ships the Swift runtime as part of the OS (/usr/lib/swift).
            // Link the shim's Swift-runtime deps against those (via .tbd stubs)
            // plus the system Foundation framework.
            println!("cargo:rustc-link-search=native=/usr/lib/swift");
            for l in [
                "swiftCore",
                "swiftSwiftOnoneSupport",
                "swift_StringProcessing",
                "swift_Concurrency",
            ] {
                println!("cargo:rustc-link-lib=dylib={l}");
            }
            // Swift code built for an older deployment target than the compiler
            // emits __swift_FORCE_LOAD_$_swiftCompatibilityNN symbols; those are
            // defined in the toolchain's static compatibility archives
            // (usr/lib/swift_static/macosx/libswiftCompatibility*.a).
            if let Ok(u) = &usrlib {
                let compat_dir = Path::new(u).join("swift_static/macosx");
                if compat_dir.is_dir() {
                    println!("cargo:rustc-link-search=native={}", compat_dir.display());
                    if let Ok(entries) = fs::read_dir(&compat_dir) {
                        for e in entries.flatten() {
                            let n = e.file_name().to_string_lossy().to_string();
                            if n.starts_with("libswiftCompatibility") && n.ends_with(".a") {
                                if let Some(stem) = n
                                    .strip_prefix("lib")
                                    .and_then(|s| s.strip_suffix(".a"))
                                {
                                    println!("cargo:rustc-link-lib=static={stem}");
                                }
                            }
                        }
                    }
                } else {
                    println!("cargo:warning=SWIFTFMT: compat archive dir not found: {}", compat_dir.display());
                }
            }
            for f in ["Foundation", "CoreFoundation"] {
                println!("cargo:rustc-link-lib=framework={f}");
            }
        }
        other => panic!("unknown SWIFTFMT_MODE: {other}"),
    }

    if let Ok(extra) = env::var("SWIFTFMT_EXTRA_LIBS") {
        for l in extra.split_whitespace() {
            println!("cargo:rustc-link-lib={l}");
        }
    }
    if let Ok(extra) = env::var("SWIFTFMT_EXTRA_FRAMEWORKS") {
        for f in extra.split_whitespace() {
            println!("cargo:rustc-link-lib=framework={f}");
        }
    }
    if let Ok(extra) = env::var("SWIFTFMT_EXTRA_LINK_ARGS") {
        for a in extra.split_whitespace() {
            println!("cargo:rustc-link-arg={a}");
        }
    }
}
