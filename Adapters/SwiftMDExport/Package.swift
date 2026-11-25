// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(name: "SwiftMDExport", products: [.library(name: "SwiftMDExport", targets: ["SwiftMDExport"])], targets: [.target(name: "SwiftMDExport"), .testTarget(name: "SwiftMDExportTests", dependencies: ["SwiftMDExport"])], swiftLanguageModes: [.v6])
