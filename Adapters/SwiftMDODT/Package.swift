// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMDODT",
    products: [.library(name: "SwiftMDODT", targets: ["SwiftMDODT"])],
    dependencies: [.package(url: "https://github.com/ThorFuchs/Swift-GFM.git", exact: "1.1.0")],
    targets: [
        .target(name: "SwiftMDODT", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")]),
        .testTarget(name: "SwiftMDODTTests", dependencies: ["SwiftMDODT"])
    ],
    swiftLanguageModes: [.v6]
)
