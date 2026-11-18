// SPDX-License-Identifier: Apache-2.0
// This target is built only by a mirror generated with --include-locked-renderers.
import Foundation
import SwiftMDBlocks
#if canImport(JavaScriptCore)
import SwiftMDJavaScriptCore
#elseif os(Linux)
import SwiftMDCompiler
#endif

public enum IntegratedRendererError: Error, Sendable {
    case missingResource(String)
    case nodeExecutableRequired
    case unsupportedPlatform
}

/// A convenience entry point using locked, bundled KaTeX and Pele scripts.
///
/// Apple platforms use JavaScriptCore. Linux requires an explicitly supplied,
/// trusted absolute Node executable. These backends execute code at compile
/// time and do not provide hard time or memory limits. `svgPrefix` must be
/// unique across all fragments placed on a page. Diagnostics must be checked.
public enum SwiftMDIntegrated {
    public static func render(_ markdown: String, svgPrefix: String, nodeExecutable: String? = nil) throws -> BlockResult {
        #if canImport(JavaScriptCore)
        let katex = try String(contentsOf: resource("katex", "cjs"), encoding: .utf8)
        let pele = try String(contentsOf: resource("pele.global", "js"), encoding: .utf8)
        return try SwiftMDAppleRenderer(katexScript: katex, peleScript: pele, svgPrefix: svgPrefix).render(markdown)
        #elseif os(Linux)
        guard let nodeExecutable else { throw IntegratedRendererError.nodeExecutableRequired }
        let katex = try resource("katex", "cjs").path
        let pele = try resource("pele", "mjs").path
        return try SwiftMDRenderer(math: NodeModule(node: nodeExecutable, module: katex),
                                   mermaid: MermaidOptions(runtime: NodeModule(node: nodeExecutable, module: pele), svgPrefix: svgPrefix)).render(markdown)
        #else
        throw IntegratedRendererError.unsupportedPlatform
        #endif
    }

    private static func resource(_ name: String, _ ext: String) throws -> URL {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: "Resources") else {
            throw IntegratedRendererError.missingResource("\(name).\(ext)")
        }
        return url
    }
}
