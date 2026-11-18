// swift-tools-version: 6.1
// SPDX-License-Identifier: Apache-2.0
import PackageDescription
let package = Package(
    name: "SwiftMDCLI",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [.executable(name: "swift-md", targets: ["SwiftMDCLI"])],
    dependencies: [
        .package(name: "Swift-MD", path: "../.."),
        .package(name: "SwiftMDBlocks", path: "../../Adapters/SwiftMDBlocks"),
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", exact: "1.0.1")
    ],
    targets: [.executableTarget(name: "SwiftMDCLI", dependencies: [
        .product(name: "SwiftMD", package: "Swift-MD"),
        .product(name: "SwiftGFM", package: "Swift-GFM"),
        .product(name: "SwiftMDBlocks", package: "SwiftMDBlocks"),
        .product(name: "SwiftMDHighlight", package: "SwiftMDBlocks"),
        .product(name: "SwiftMDKaTeXNode", package: "SwiftMDBlocks"),
        .product(name: "SwiftMDPeleNode", package: "SwiftMDBlocks")
    ])], swiftLanguageModes: [.v6]
)
