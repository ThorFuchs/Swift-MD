// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMDEPUB",
    platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v16), .watchOS(.v9), .visionOS(.v1)],
    products: [.library(name: "SwiftMDEPUB", targets: ["SwiftMDEPUB"])],
    dependencies: [
        .package(url: "https://github.com/ThorFuchs/Swift-GFM.git", exact: "1.1.0"),
        // Exact initial candidate, supports Swift 6.0; isolated from SwiftMD Core.
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.2.0")
    ],
    targets: [
        .target(name: "SwiftMDEPUB", dependencies: [
            .product(name: "SwiftGFM", package: "Swift-GFM"),
            .product(name: "Crypto", package: "swift-crypto")
        ]),
        .testTarget(name: "SwiftMDEPUBTests", dependencies: ["SwiftMDEPUB"],
                    resources: [.copy("Fixtures")])
    ],
    swiftLanguageModes: [.v6]
)
