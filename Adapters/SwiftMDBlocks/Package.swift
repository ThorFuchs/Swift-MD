// swift-tools-version: 6.1
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "SwiftMDBlocks",
    products: [
        .library(name: "SwiftMDBlocks", targets: ["SwiftMDBlocks"]),
        .library(name: "SwiftMDHighlight", targets: ["SwiftMDHighlight"]),
    ],
    dependencies: [
        .package(name: "Swift-MD", path: "../.."),
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", revision: "d1c262f42daa7a06f4612a94671e10740e26d09a"),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", revision: "d86f244ed497d48012782e2f59c985a55e77b3f5"),
        .package(url: "https://github.com/nicklockwood/LRUCache.git", exact: "1.3.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", exact: "1.3.1"),
        .package(url: "https://github.com/ThorFuchs/Swift-Highlight.git", revision: "be6b555fed12d15af337facfc0ca4b3d8b4ba6b5"),
    ],
    targets: [
        .target(name: "SwiftMDBlocks", dependencies: [.product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftSoup", package: "SwiftSoup")]),
        .target(name: "SwiftMDHighlight", dependencies: ["SwiftMDBlocks", .product(name: "SwiftHighlight", package: "Swift-Highlight"), .product(name: "SwiftHighlightHTML", package: "Swift-Highlight")]),
        .testTarget(name: "SwiftMDBlocksTests", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", .product(name: "SwiftSoup", package: "SwiftSoup"), .product(name: "SwiftGFM", package: "Swift-GFM"), .product(name: "SwiftMD", package: "Swift-MD")]),
    ], swiftLanguageModes: [.v6]
)
