// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMDDOCX",
    products: [.library(name: "SwiftMDDOCX", targets: ["SwiftMDDOCX"])],
    dependencies: [.package(url: "https://github.com/ThorFuchs/Swift-GFM.git", exact: "1.1.0")],
    targets: [
        .target(name: "SwiftMDDOCX", dependencies: [.product(name: "SwiftGFM", package: "Swift-GFM")]),
        .testTarget(name: "SwiftMDDOCXTests", dependencies: ["SwiftMDDOCX"], resources: [.copy("Fixtures")]),
    ],
    swiftLanguageModes: [.v6]
)
