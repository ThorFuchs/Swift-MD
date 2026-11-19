// swift-tools-version: 6.1
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "SwiftMDBlocks",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "SwiftMDBlocks", targets: ["SwiftMDBlocks"]),
        .library(name: "SwiftMDHighlight", targets: ["SwiftMDHighlight"]),
        .library(name: "SwiftMDKaTeXNode", targets: ["SwiftMDKaTeXNode"]),
        .library(name: "SwiftMDPeleNode", targets: ["SwiftMDPeleNode"]),
        .library(name: "SwiftMDCompiler", targets: ["SwiftMDCompiler"]),
        .library(name: "SwiftMDJavaScriptCore", targets: ["SwiftMDJavaScriptCore"]),
    ],
    dependencies: [
        .package(name: "Swift-MD", path: "../.."),
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", exact: "1.0.1"),
        .package(url: "https://github.com/nicklockwood/LRUCache.git", exact: "1.3.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", exact: "1.3.1"),
        .package(url: "https://github.com/ThorFuchs/Swift-Highlight.git", exact: "1.0.1"),
    ],
    targets: [
        .target(name: "SwiftMDSoup", dependencies: [.product(name: "LRUCache", package: "LRUCache"), .product(name: "Atomics", package: "swift-atomics")], path: "Vendor/SwiftSoup", exclude: ["UPSTREAM.json"], sources: ["Sources"], resources: [.copy("LICENSE"), .copy("JSOUP-LICENSE.txt")], swiftSettings: [.swiftLanguageMode(.v5)]),
        .target(name: "SwiftMDBlocks", dependencies: [.product(name: "SwiftMD", package: "Swift-MD"), "SwiftMDSoup"]),
        .target(name: "SwiftMDPeleNode", dependencies: ["SwiftMDBlocks", "SwiftMDKaTeXNode"]),
        .target(name: "SwiftMDKaTeXNode", dependencies: ["SwiftMDBlocks"]),
        .target(name: "SwiftMDHighlight", dependencies: ["SwiftMDBlocks", .product(name: "SwiftHighlight", package: "Swift-Highlight"), .product(name: "SwiftHighlightHTML", package: "Swift-Highlight")]),
        .target(name: "SwiftMDCompiler", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", .product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftGFM", package: "Swift-GFM")]),
        .target(name: "SwiftMDJavaScriptCore", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", .product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftGFM", package: "Swift-GFM")]),
        .testTarget(name: "SwiftMDBlocksTests", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", "SwiftMDCompiler", "SwiftMDJavaScriptCore", "SwiftMDSoup", .product(name: "SwiftGFM", package: "Swift-GFM"), .product(name: "SwiftMD", package: "Swift-MD")]),
    ], swiftLanguageModes: [.v6]
)
