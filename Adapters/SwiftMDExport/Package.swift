// swift-tools-version: 6.0
// SPDX-License-Identifier: Apache-2.0
import PackageDescription

let package = Package(name: "SwiftMDExport", platforms: [.macOS(.v13), .iOS(.v16)], products: [.library(name: "SwiftMDExport", targets: ["SwiftMDExport"])], targets: [.target(name: "SwiftMDExport"), .testTarget(name: "SwiftMDExportTests", dependencies: ["SwiftMDExport"])], swiftLanguageModes: [.v6])
