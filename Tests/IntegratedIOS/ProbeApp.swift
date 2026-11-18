// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftUI
import SwiftMDBundled

@main
struct IntegratedProbeApp: App {
    let message = runProbe()
    var body: some Scene { WindowGroup { Text(message).padding() } }
}

private func runProbe() -> String {
    let message: String
    do {
        let source = "| A | B |\n| - | - |\n| x | y |\n\n```swift\nlet value = 1\n```\n\n```math\nx^2\n```\n\n```mermaid\nflowchart LR\nA-->B\n```\n"
        let result = try SwiftMDIntegrated.render(source, svgPrefix: "ios-page")
        let expected = ["<table>", "hljs-keyword", "<math", "<svg", "viewBox=", "id=\"ios-page-2\""]
        guard result.diagnostics.isEmpty, expected.allSatisfy({ result.html.contains($0) }),
              !result.html.contains("<script") else { throw ProbeError.combined }
        let failed = try SwiftMDIntegrated.render("```math\n\\badcommand{<script>}\n```\n", svgPrefix: "ios-bad")
        guard failed.diagnostics.count == 1, failed.html.contains("&lt;script&gt;"),
              !failed.html.contains("<script>") else { throw ProbeError.fallback }
        message = "PASS: bundled SwiftMD table, highlight, MathML, SVG and fallback"
    } catch {
        message = "FAIL: \(error)"
    }
    if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        try? FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
        try? message.write(to: documents.appendingPathComponent("swiftmd-probe-result.txt"), atomically: true, encoding: .utf8)
    }
    return message
}

private enum ProbeError: Error { case combined, fallback }
