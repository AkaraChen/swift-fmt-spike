// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "swiftformat-wasm",
  dependencies: [
    .package(path: "../swift-format")
  ],
  targets: [
    .executableTarget(
      name: "swiftformat_wasm",
      dependencies: [
        .product(name: "SwiftFormat", package: "swift-format")
      ],
      swiftSettings: [
        .swiftLanguageMode(.5)
      ],
      linkerSettings: [
        .unsafeFlags([
          "-Xlinker", "--export=swiftformat_format",
          "-Xlinker", "--export=swiftformat_out_ptr",
          "-Xlinker", "--export=swiftformat_out_len",
          "-Xlinker", "--export=swiftformat_err_ptr",
          "-Xlinker", "--export=swiftformat_err_len",
          "-Xlinker", "--export=swiftformat_alloc",
          "-Xlinker", "--export=swiftformat_wasm_version",
        ])
      ]
    )
  ]
)
