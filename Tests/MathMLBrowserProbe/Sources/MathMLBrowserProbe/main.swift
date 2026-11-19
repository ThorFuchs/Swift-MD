// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftMDKaTeXNode

let environment = ProcessInfo.processInfo.environment
guard let node = environment["SWIFTMD_NODE"], let module = environment["SWIFTMD_KATEX"] else {
    fatalError("Set SWIFTMD_NODE and SWIFTMD_KATEX to trusted absolute paths")
}
let renderer = try KaTeXNodeRenderer(node: node, module: module)
let tex = #"\frac{x_1}{y^2} + \text{<tag> \& hello}"#
let inline = try renderer.renderMath(literal: tex, displayMode: false)
let display = try renderer.renderMath(literal: tex, displayMode: true)
let json = try JSONSerialization.data(withJSONObject: ["inline": inline, "display": display], options: [.sortedKeys])
FileHandle.standardOutput.write(json)
