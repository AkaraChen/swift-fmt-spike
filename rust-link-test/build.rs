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

/// Link-order rank for the Swift static runtime archives (GNU ld single pass:
/// dependents must precede their dependencies).
fn archive_rank(n: &str) -> u8 {
    match n {
        "swiftCore" => 0,
        "swiftSwiftOnoneSupport" => 1,
        "Foundation" | "FoundationXML" | "FoundationNetworking" => 2,
        "FoundationEssentials" => 3,
        "FoundationInternationalization" => 4,
        "_FoundationCollections" => 5,
        "CoreFoundation" | "_FoundationCShims" | "_CFXMLInterface" | "_CFURLSessionInterface"
        | "DispatchStubs" => 6,
        "_FoundationICU" => 7,
        n if n.starts_with("swift") => 8,
        "dispatch" | "BlocksRuntime" => 9,
        _ => 10,
    }
}

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
            // are only pulled in when actually referenced, but ORDER MATTERS:
            // with GNU ld's single pass, an archive must come after every
            // archive that references its members. The order below mirrors
            // the Foundation layering (overlay -> Essentials ->
            // Internationalization -> ICU -> CF shims).
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
            names.sort_by_key(|n| archive_rank(n));
            // GNU ld's single pass cannot satisfy CYCLIC references between the
            // Swift archives (e.g. FoundationEssentials <->
            // FoundationInternationalization: Date.nextUp/nextDown are defined
            // in one and referenced from FormatStyle code in the other, in
            // both directions, so no static ordering works). Re-listing the
            // whole set a few times makes ld rescan until a fixed point, the
            // classic pre---start-group trick.
            for _ in 0..3 {
                for n in &names {
                    println!("cargo:rustc-link-lib=static={n}");
                }
            }

            // swiftrt.o registers the Swift runtime resource sections
            // (protocol conformances, reflection) via its constructors; Swift's
            // own driver always links it for executables. Without it, pure-Swift
            // code linked into a foreign (Rust) main segfaults on first
            // metadata access. It is a bare .o, so its position on the link
            // line only affects resolution order, and end placement resolves
            // fine against the archives above.
            if let Ok(rt) = env::var("SWIFTFMT_SWIFTRT_O") {
                if Path::new(&rt).exists() {
                    println!("cargo:rustc-link-arg={rt}");
                } else {
                    println!("cargo:warning=SWIFTFMT: swiftrt.o not found at {rt}");
                }
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
            // defined in static compatibility archives shipped with the toolchain
            // (location found by the workflow via `find`, passed as
            // SWIFTFMT_COMPAT_DIR).
            if let Ok(dir) = env::var("SWIFTFMT_COMPAT_DIR") {
                let mut d = PathBuf::from(&dir);
                // Xcode ships per-platform copies of the compatibility
                // archives under usr/lib/swift/<platform>; a `find` may land
                // on e.g. xros, whose objects ld rejects ("building for
                // macOS, but linking in object built for visionOS") or whose
                // fat files lack our arch. Prefer the macosx directory.
                if d.file_name().map(|n| n != "macosx").unwrap_or(true) {
                    let macosx = d
                        .parent()
                        .map(|p| p.join("macosx"))
                        .filter(|c| c.is_dir());
                    d = macosx.unwrap_or(d);
                }
                if d.is_dir() {
                    println!("cargo:rustc-link-search=native={}", d.display());
                    if let Ok(entries) = fs::read_dir(&d) {
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
                    println!("cargo:warning=SWIFTFMT: SWIFTFMT_COMPAT_DIR is not a directory: {dir}");
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
