#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

import Foundation
import SwiftFormat

// C ABI shim around apple/swift-format 604.0.0 for Rust (or any C-ABI) consumers.
//
// Public API (see SwiftFmtShim.h):
//   const char *swiftfmt_version(void);
//   char *swiftfmt_format(const char *input, const char *filename);
//   void swiftfmt_free(char *ptr);

/// Exact apple/swift-format API used (verified against the 604.0.0 tag):
///
///   let formatter = SwiftFormatter(configuration: Configuration(), findingConsumer: nil)
///   var buffer = ""
///   try formatter.format(
///       source: source,                       // String
///       assumingFileURL: URL(fileURLWithPath: filename),
///       selection: .infinite,
///       experimentalFeatures: [],
///       to: &buffer,                          // TextOutputStream (String)
///       parsingDiagnosticHandler: nil)
///
/// Parse errors surface as a thrown `SwiftFormatError.fileContainsInvalidSyntax`
/// (the SwiftParser-based pipeline is error-*recovering*, but swift-format's
/// `parseAndEmitDiagnostics` throws when any parser error was reported).
/// We map every thrown error to a NULL return.
///
/// Thread safety: a fresh SwiftFormatter (and the parser it owns) is created
/// per call, so no shared mutable formatter state is touched across calls.
/// Only truly global state is the lazily-initialized `versionCString`, which
/// Swift initializes once under a runtime lock.

/// Leaked singleton so `swiftfmt_version()` can return a pointer that outlives
/// the call. Global `let` initialization is guarded by `swift_once` (thread-safe).
private let versionCString: UnsafePointer<CChar> = {
    let s = "swiftfmt-shim 1.0.0 + apple/swift-format 604.0.0"
    guard let p = strdup(s) else { fatalError("strdup failed") }
    return UnsafePointer(p)
}()

@_cdecl("swiftfmt_version")
public func swiftfmt_version() -> UnsafePointer<CChar>? {
    return versionCString
}

@_cdecl("swiftfmt_format")
public func swiftfmt_format(
    input: UnsafePointer<CChar>?,
    filename: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>? {
    guard let inputC = input else { return nil }
    guard let source = String(validatingUTF8: inputC) else { return nil }

    let filename = filename.flatMap { String(validatingUTF8: $0) } ?? "source.swift"
    let assumedURL = URL(fileURLWithPath: filename)

    let formatter = SwiftFormatter(configuration: Configuration(), findingConsumer: nil)
    var buffer = ""
    do {
        try formatter.format(
            source: source,
            assumingFileURL: assumedURL,
            selection: .infinite,
            experimentalFeatures: [],
            to: &buffer,
            parsingDiagnosticHandler: nil
        )
    } catch {
        // Includes SwiftFormatError.fileContainsInvalidSyntax for unparsable code.
        return nil
    }
    // Caller frees with swiftfmt_free() -> free().
    return strdup(buffer)
}

@_cdecl("swiftfmt_free")
public func swiftfmt_free(ptr: UnsafeMutablePointer<CChar>?) {
    if let p = ptr {
        free(p)
    }
}
