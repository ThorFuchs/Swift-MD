// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMDTypst",
    products: [.library(name: "SwiftMDTypst", targets: ["SwiftMDTypst"])],
    dependencies: [
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", exact: "1.1.0")
    ],
    targets: [
        .target(name: "SwiftMDTypst", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")]),
        .testTarget(name: "SwiftMDTypstTests", dependencies: ["SwiftMDTypst"]),
        .executableTarget(name: "SwiftMDTypstProof", dependencies: ["SwiftMDTypst"])
    ],
    swiftLanguageModes: [.v6]
)
