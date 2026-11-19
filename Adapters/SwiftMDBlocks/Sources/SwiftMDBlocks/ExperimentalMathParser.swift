// SPDX-License-Identifier: Apache-2.0
#if SWIFTMD_EXPERIMENTAL_GFM_MATH
import SwiftGFM

extension BlockCompiler {
    /// Local integration prototype. Requires an unreleased SwiftGFM math parser.
    /// Not enabled for public builds until a matching SwiftGFM release exists.
    public func renderRecognizingMath(_ source: String, mathRenderer: any MathMLRenderer) throws -> BlockResult {
        let parsed = try MarkdownEngine(configuration: compiler.configuration).renderRecognizingMath(source)
        let parts: [MathDocumentPart] = parsed.parts.map { part in
            switch part {
            case .html(let html): .html(html)
            case .math(let math): .math(.init(index: math.index, literal: math.literal,
                                               source: math.source, displayMode: math.displayMode))
            }
        }
        // Preserve the existing block profile when the parser found no math.
        if !parsed.parts.contains(where: { if case .math = $0 { true } else { false } }) {
            return try render(source)
        }
        return try render(parts, mathRenderer: mathRenderer)
    }
}
#endif
