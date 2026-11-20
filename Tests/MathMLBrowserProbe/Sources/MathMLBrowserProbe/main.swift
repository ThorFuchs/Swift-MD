// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftMDKaTeXNode
import SwiftMDBlocks
import SwiftMDHighlight

let environment = ProcessInfo.processInfo.environment
guard let node = environment["SWIFTMD_NODE"], let module = environment["SWIFTMD_KATEX"] else {
    fatalError("Set SWIFTMD_NODE and SWIFTMD_KATEX to trusted absolute paths")
}
let renderer = try KaTeXNodeRenderer(node: node, module: module)
let tex = #"\frac{x_1}{y^2} + \text{<tag> \& hello}"#
let parts: [MathDocumentPart] = [
    .html("<p id=\"swiftmd-inline-math\">Before "),
    .math(.init(index: 0, literal: tex, source: "$x$", displayMode: false)),
    .html(" after</p><div id=\"swiftmd-display-math\">"),
    .math(.init(index: 1, literal: tex, source: "$$x$$", displayMode: true)),
    .html("</div>")
]
let result = try BlockCompiler(renderers: [HighlightRenderer()]).render(parts, mathRenderer: renderer)
guard result.diagnostics.isEmpty else { fatalError("MathML probe failed: \(result.diagnostics)") }
let json = try JSONSerialization.data(withJSONObject: ["composed": result.html], options: [.sortedKeys])
FileHandle.standardOutput.write(json)
