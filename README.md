# swift-fmt-spike

Feasibility spike: **can apple/swift-format be linked into a Rust binary as a
static library (C ABI) — with the Swift runtime wired up per platform — so that
[fama](https://github.com/AkaraChen/fama) can format Swift in-process instead
of shelling out to a CLI?**

## What's here

| Path | What it is |
|---|---|
| `Package.swift` | Swift package `SwiftFmtShim` — a **static library** product wrapping [swiftlang/swift-format](https://github.com/swiftlang/swift-format) **604.0.0** (its `SwiftFormat` module + swift-syntax + swift-markdown objects all end up inside `libSwiftFmtShim.a`) |
| `Sources/SwiftFmtShim/Shim.swift` | C ABI via `@_cdecl`: `swiftfmt_format` / `swiftfmt_free` / `swiftfmt_version` |
| `SwiftFmtShim.h` | The consumer header (also uploaded as CI artifact) |
| `rust-link-test/` | Tiny cargo project whose build.rs consumes env-configured link flags; `main.rs` formats a sample, checks error paths, idempotency, 50-call latency and 4-thread concurrency |
| `.github/workflows/ci.yml` | Matrix CI: builds the `.a`, discovers the exact Swift runtime linkage, runs the **Rust link test on the runner itself**, and uploads `.a` + header + proven link line as artifacts |

## C ABI surface

```c
const char *swiftfmt_version(void);                      // static string, do not free
char *swiftfmt_format(const char *input, const char *filename); // malloc'd result or NULL
void swiftfmt_free(char *ptr);                           // free() on the Rust side's behalf
```

Exact apple/swift-format API used (604.0.0, single `SwiftFormat` module):

```swift
let formatter = SwiftFormatter(configuration: Configuration(), findingConsumer: nil)
var buffer = ""
try formatter.format(
    source: source,
    assumingFileURL: URL(fileURLWithPath: filename),
    selection: .infinite,
    experimentalFeatures: [],
    to: &buffer,
    parsingDiagnosticHandler: nil)
```

- `Configuration()` = swift-format defaults; fama can map its own
  `FormatConfig` (indent, line length) onto `Configuration` fields later.
- Parse errors throw `SwiftFormatError.fileContainsInvalidSyntax` → the shim
  returns NULL (like the CLI's "unparsable file" behavior).
- A fresh `SwiftFormatter` + parser is created **per call** — no shared mutable
  state, so concurrent calls from multiple Rust threads are safe (verified in
  the link test).

## Platform strategy

- **Linux**: toolchain from swift.org (Swift 6.1.2, x86_64 + aarch64). The
  Swift runtime is linked **statically** from `usr/lib/swift_static/linux/*.a`
  (swiftCore, swiftSwiftOnoneSupport, swift_StringProcessing, swift_Concurrency,
  swiftGlibc, swiftFoundation, swiftFoundationICU, dispatch, BlocksRuntime) +
  the C++ runtime swiftCore was built against. All archives present in that
  directory are linked; ld pulls only the members actually referenced.
- **macOS**: the OS itself ships the Swift runtime (`/usr/lib/swift`), so the
  Rust binary links `libswiftCore.tbd` etc. and the system `Foundation`
  framework — no bundled runtime needed for macOS ≥ the Swift version in the
  OS. (Apple does not ship static Swift runtime archives for macOS at all, so
  "static runtime" is not an option there; "no runtime to ship" is the prize.)
- **Windows**: not attempted. A Swift static library consumable by MSVC
  (`.lib`, Swift runtime DLL/static libs, clang-rt, libc++) is a project of its
  own — marked unsupported for now.

## Results

_TBD — filled in after the first green CI run; see the run logs for the exact
per-platform evidence._
