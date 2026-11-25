// swift-tools-version:6.0
import PackageDescription

// Static-library product: `swift build -c release` produces
// libSwiftFmtShim.a containing this target AND all of its dependencies
// (apple/swift-format 604.0.0, swift-syntax 604.x, swift-markdown).
// Only the Swift *runtime* remains external to the archive, which is
// exactly what the Rust link-test in ./rust-link-test experiments with.
let package = Package(
    name: "SwiftFmtShim",
    platforms: [
        // swift-format 604.0.0 requires macOS 13.0; without an explicit
        // platform declaration the package defaults to 10.13 and SPM refuses.
        .macOS("13.0")
    ],
    products: [
        .library(name: "SwiftFmtShim", type: .static, targets: ["SwiftFmtShim"])
    ],
    dependencies: [
        // Exact pin via a single-version closed range (the `exactVersion:`
        // overload does not exist in the tools-6.0 ManifestAPI).
        .package(url: "https://github.com/swiftlang/swift-format.git", Version(604, 0, 0)...Version(604, 0, 0)),
    ],
    targets: [
        .target(
            name: "SwiftFmtShim",
            dependencies: [
                .product(name: "SwiftFormat", package: "swift-format")
            ]
        ),
    ],
    swiftLanguageModes: [.v5]
)
