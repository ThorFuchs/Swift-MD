// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(
    name: "SwiftMDGalleryDOCX",
    dependencies: [.package(name: "SwiftMDDOCX", path: "../../Adapters/SwiftMDDOCX")],
    targets: [.executableTarget(name: "GalleryDOCX", dependencies: [
        .product(name: "SwiftMDDOCX", package: "SwiftMDDOCX")
    ])],
    swiftLanguageModes: [.v6]
)
