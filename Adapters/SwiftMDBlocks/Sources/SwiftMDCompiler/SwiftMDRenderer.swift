// SPDX-License-Identifier: Apache-2.0
#if os(macOS) || os(Linux)
import SwiftGFM
import SwiftMD
import SwiftMDBlocks
import SwiftMDHighlight
import SwiftMDKaTeXNode
import SwiftMDPeleNode

/// Explicit, trusted paths for a locally installed Node module.
public struct NodeModule: Sendable {
    public let node: String
    public let module: String

    public init(node: String, module: String) {
        self.node = node
        self.module = module
    }
}

/// Mermaid configuration. The prefix must be unique across a composed HTML page.
public struct MermaidOptions: Sendable {
    public let runtime: NodeModule
    public let svgPrefix: String

    public init(runtime: NodeModule, svgPrefix: String) {
        self.runtime = runtime
        self.svgPrefix = svgPrefix
    }
}

/// Combines optional renderers with SwiftMD's baseline compiler.
///
/// The extended profile processes HTML and may serialize it differently. When
/// all renderers are disabled, the baseline SwiftGFM bytes are preserved.
/// Renderer failures retain the original escaped block and produce diagnostics.
/// Node and module paths are trusted configuration; Node is not sandboxed.
public struct SwiftMDRenderer: Sendable {
    private let compiler: BlockCompiler
    #if SWIFTMD_EXPERIMENTAL_GFM_MATH
    private let mathRenderer: KaTeXNodeRenderer?
    #endif

    public init(
        configuration: MarkdownConfiguration = .gfm,
        highlight: Bool = true,
        math: NodeModule? = nil,
        mermaid: MermaidOptions? = nil
    ) throws {
        var renderers: [any BlockRenderer] = []
        #if SWIFTMD_EXPERIMENTAL_GFM_MATH
        var prototypeMathRenderer: KaTeXNodeRenderer?
        #endif
        if let math {
            let renderer = try KaTeXNodeRenderer(node: math.node, module: math.module)
            renderers.append(renderer)
            #if SWIFTMD_EXPERIMENTAL_GFM_MATH
            prototypeMathRenderer = renderer
            #endif
        }
        if let mermaid {
            renderers.append(try PeleNodeRenderer(node: mermaid.runtime.node, module: mermaid.runtime.module, prefix: mermaid.svgPrefix))
        }
        if highlight { renderers.append(HighlightRenderer()) }
        compiler = BlockCompiler(compiler: MarkdownCompiler(configuration: configuration), renderers: renderers)
        #if SWIFTMD_EXPERIMENTAL_GFM_MATH
        self.mathRenderer = prototypeMathRenderer
        #endif
    }

    /// Compile Markdown to HTML and diagnostics in one call.
    public func render(_ markdown: String) throws -> BlockResult {
        #if SWIFTMD_EXPERIMENTAL_GFM_MATH
        if let mathRenderer { return try compiler.renderRecognizingMath(markdown, mathRenderer: mathRenderer) }
        #endif
        return try compiler.render(markdown)
    }
}
#endif
