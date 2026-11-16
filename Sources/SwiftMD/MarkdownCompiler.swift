// SPDX-License-Identifier: Apache-2.0
import SwiftGFM

/// An HTML fragment and diagnostics produced by the compiler.
public struct MarkdownResult: Sendable {
    public let html: String
    /// The baseline compiler has no additional diagnostics. SwiftGFM errors are thrown.
    public let diagnostics: [String]
}

/// A synchronous, value-type facade over SwiftGFM's cmark-gfm renderer.
///
/// The baseline passes the configuration through unchanged and returns the exact
/// backend HTML. SwiftGFM serializes access to its backend across concurrent calls.
/// Raw HTML, URLs, and resource limits follow the supplied configuration; the
/// output is not a sanitizer. No block extensions are implemented yet.
public struct MarkdownCompiler: Sendable {
    public let configuration: MarkdownConfiguration

    public init(configuration: MarkdownConfiguration = .gfm) {
        self.configuration = configuration
    }

    /// Render a fragment, propagating configuration and backend errors.
    public func render(_ source: String) throws -> MarkdownResult {
        let html = try MarkdownEngine(configuration: configuration).render(source, as: .html)
        return MarkdownResult(html: html, diagnostics: [])
    }
}
