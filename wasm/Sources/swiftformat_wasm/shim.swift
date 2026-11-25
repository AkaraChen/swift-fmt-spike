//===----------------------------------------------------------------------===//
// swiftformat-wasm shim: minimal C ABI around the SwiftFormat library.
//
// ABI:
//   swiftformat_alloc(len: i32) -> ptr: i32                 host allocates input scratch
//   swiftformat_format(srcPtr: i32, srcLen: i32,
//                      cfgPtr: i32, cfgLen: i32) -> packed: i64
//       >= 0: success, packed low 32 bits = output length (UTF-8, via out_ptr/out_len)
//       <  0: error; error message UTF-8 via err_ptr/err_len
//             -1 = config decode error, -2 = format error, -3 = unknown error
//   swiftformat_out_ptr() -> ptr: i32
//   swiftformat_out_len() -> len: i32
//   swiftformat_err_ptr() -> ptr: i32
//   swiftformat_err_len() -> len: i32
//   swiftformat_wasm_version() -> version: i32   (packed major*10000+minor*100+patch-ish marker)
//
// cfg JSON: SwiftFormat Configuration JSON (https://github.com/swiftlang/swift-format);
// cfgLen == 0 uses Configuration() defaults. Exercises JSONDecoder either way.
//===----------------------------------------------------------------------===//

import Foundation
import SwiftFormat

/// Accumulating TextOutputStream.
struct ByteStream: TextOutputStream {
  var bytes: [UInt8] = []
  mutating func write(_ string: String) {
    bytes.append(contentsOf: string.utf8)
  }
}

// Module-owned output/error buffers; pointers stay stable between calls as long
// as the host does not call format again (single-threaded contract).
@main
struct ShimMain {
  static func main() {}  // host drives everything through the exported C ABI
}

nonisolated(unsafe) var outBuffer: [UInt8] = []
nonisolated(unsafe) var errBuffer: [UInt8] = []

@_cdecl("swiftformat_alloc")
public func swiftformat_alloc(_ len: Int32) -> UnsafeMutableRawPointer? {
  return UnsafeMutableRawPointer.allocate(byteCount: Int(len), alignment: 16)
}

@_cdecl("swiftformat_format")
public func swiftformat_format(
  _ srcPtr: UnsafeRawPointer, _ srcLen: Int32,
  _ cfgPtr: UnsafeRawPointer?, _ cfgLen: Int32
) -> Int64 {
  // Decode configuration (or defaults). Exercises JSONDecoder on every call.
  var configuration: Configuration
  if let cfgPtr, cfgLen > 0 {
    let cfgData = Data(bytes: cfgPtr, count: Int(cfgLen))
    do {
      configuration = try Configuration(data: cfgData)
    } catch {
      errBuffer = Array("config decode error: \(error)".utf8)
      return -1
    }
  } else {
    configuration = Configuration()
  }

  let source = String(decoding: srcPtr.bindMemory(to: UInt8.self, capacity: Int(srcLen)), as: UTF8.self)

  let formatter = SwiftFormatter(configuration: configuration)
  var stream = ByteStream()
  let url = URL(fileURLWithPath: "input.swift")  // dummy URL; probe: does format() touch FileManager?
  do {
    try formatter.format(
      source: source,
      assumingFileURL: url,
      selection: .infinite,
      to: &stream
    )
  } catch {
    errBuffer = Array("format error: \(error)".utf8)
    if error is SwiftFormatError { return -2 }
    return -3
  }
  outBuffer = stream.bytes
  return Int64(outBuffer.count)
}

@_cdecl("swiftformat_out_ptr")
public func swiftformat_out_ptr() -> UnsafeRawPointer? {
  return outBuffer.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
}

@_cdecl("swiftformat_out_len")
public func swiftformat_out_len() -> Int32 {
  return Int32(outBuffer.count)
}

@_cdecl("swiftformat_err_ptr")
public func swiftformat_err_ptr() -> UnsafeRawPointer? {
  return errBuffer.withUnsafeBufferPointer { UnsafeRawPointer($0.baseAddress) }
}

@_cdecl("swiftformat_err_len")
public func swiftformat_err_len() -> Int32 {
  return Int32(errBuffer.count)
}

@_cdecl("swiftformat_wasm_version")
public func swiftformat_wasm_version() -> Int32 {
  return 603_000  // marker for swift-format 603.0.0
}
