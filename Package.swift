// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMD",
    products: [.library(name: "SwiftMD", targets: ["SwiftMD"]),
               .library(name: "SwiftMDTypst", targets: ["SwiftMDTypst"])],
    dependencies: [
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", from: "1.1.0")
    ],
    targets: [
        .target(name: "SwiftMD", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")]),
        .target(name: "SwiftMDTypst", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")], path: "Adapters/SwiftMDTypst/Sources/SwiftMDTypst"),
        .testTarget(name: "SwiftMDTests", dependencies: ["SwiftMD", .product(name: "SwiftGFM", package: "Swift-GFM")], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v6]
)
