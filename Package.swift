// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMD",
    products: [.library(name: "SwiftMD", targets: ["SwiftMD"])],
    dependencies: [
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", revision: "d1c262f42daa7a06f4612a94671e10740e26d09a")
    ],
    targets: [
        .target(name: "SwiftMD", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")]),
        .testTarget(name: "SwiftMDTests", dependencies: ["SwiftMD", .product(name: "SwiftGFM", package: "Swift-GFM")], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v6]
)
