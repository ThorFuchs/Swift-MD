// swift-tools-version: 6.1
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "MathMLBrowserProbe",
    platforms: [.macOS(.v15)],
    dependencies: [.package(name: "SwiftMDBlocks", path: "../../Adapters/SwiftMDBlocks")],
    targets: [.executableTarget(name: "MathMLBrowserProbe", dependencies: [
        .product(name: "SwiftMDKaTeXNode", package: "SwiftMDBlocks"),
        .product(name: "SwiftMDBlocks", package: "SwiftMDBlocks"),
        .product(name: "SwiftMDHighlight", package: "SwiftMDBlocks")
    ])]
)
