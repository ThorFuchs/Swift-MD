// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftMD
import SwiftHTML

/// Trusted HTML returned by a block renderer. The caller is responsible for its safety.
public enum BlockReplacement: Sendable {
    /// Replace the contents of the existing code element, preserving its attributes.
    case codeHTML(String)
    /// Replace the entire pre element.
    case blockHTML(String)
    /// A fragment accepted by the strict SVG validator, preserved byte for byte.
    case validatedSVG(ValidatedSVG)
}

/// A synchronous renderer. Calls occur in registration order; the first match wins.
/// Implementations must be safe for concurrent use and must escape untrusted input.
public protocol BlockRenderer: Sendable {
    func accepts(language: String) -> Bool
    func render(literal: String, language: String, index: Int) throws -> BlockReplacement
}

/// Renders trusted-configuration TeX to a MathML HTML fragment.
/// This renderer does not recognize Markdown delimiters; callers must supply
/// the original TeX and select inline or display layout explicitly.
public protocol MathMLRenderer: Sendable {
    func renderMath(literal: String, displayMode: Bool) throws -> String
}

/// A math occurrence supplied by a trusted, math-aware Markdown parser.
/// `source` is the original delimited spelling used for the failure fallback.
public struct MathOccurrence: Sendable {
    public let index: Int
    public let literal: String
    public let source: String
    public let displayMode: Bool

    public init(index: Int, literal: String, source: String, displayMode: Bool) {
        self.index = index
        self.literal = literal
        self.source = source
        self.displayMode = displayMode
    }
}

/// Parts of a single HTML document stream produced by a trusted parser.
/// HTML fragments may be incomplete individually. A math occurrence must be
/// placed at an HTML text or block position, never in an attribute or comment.
public enum MathDocumentPart: Sendable {
    case html(String)
    case math(MathOccurrence)
}

public struct BlockDiagnostic: Sendable, Equatable {
    public enum Kind: Sendable { case unsupportedLanguage, renderFailed, unsupportedContent }
    public let kind: Kind
    public let blockIndex: Int
    public let language: String
    public let message: String
}

public enum BlockProcessingError: Error, Sendable { case missingBody }

public struct BlockResult: Sendable {
    public let html: String
    public let diagnostics: [BlockDiagnostic]
}

/// Explicit opt-in HTML profile. It processes *all* matching pre/code elements,
/// including author-provided raw HTML. Returned HTML is reserialized by SwiftHTML.
public struct BlockCompiler: Sendable {
    public let compiler: MarkdownCompiler
    public let renderers: [any BlockRenderer]

    public init(compiler: MarkdownCompiler = .init(), renderers: [any BlockRenderer]) {
        self.compiler = compiler
        self.renderers = renderers
    }

    public func render(_ source: String) throws -> BlockResult {
        let original = try compiler.render(source).html
        return try processHTML(original)
    }

    /// Render a document stream from a trusted math-aware parser. Raw HTML and
    /// renderer output remain explicit caller trust boundaries. This method
    /// does not recognize Markdown math delimiters on its own.
    public func render(_ parts: [MathDocumentPart], mathRenderer: any MathMLRenderer) throws -> BlockResult {
        let original = parts.map { part in
            switch part { case .html(let html): html; case .math(let math): math.source }
        }.joined()
        var html = ""
        var replacements: [(String, String)] = []
        var diagnostics: [BlockDiagnostic] = []
        for part in parts {
            switch part {
            case .html(let fragment):
                html += fragment
            case .math(let math):
                let replacement: String
                do {
                    let rendered = try mathRenderer.renderMath(literal: math.literal, displayMode: math.displayMode)
                    guard !rendered.isEmpty, rendered.contains("<math") else { throw MathFragmentError.invalidOutput }
                    replacement = rendered
                } catch {
                    let escaped = math.source.replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                    replacement = math.displayMode ? "<pre><code>\(escaped)</code></pre>" : escaped
                    diagnostics.append(.init(kind: .renderFailed, blockIndex: math.index,
                                             language: "math", message: String(describing: error)))
                }
                var marker: String
                repeat { marker = "SWIFTMDMATH" + UUID().uuidString.replacingOccurrences(of: "-", with: "") }
                while original.contains(marker) || replacements.contains(where: { $0.0 == marker || $0.1.contains(marker) })
                html += marker
                replacements.append((marker, replacement))
            }
        }
        let processed = try processHTML(html)
        html = processed.html
        for (marker, replacement) in replacements {
            guard let range = html.range(of: marker),
                  html.range(of: marker, range: range.upperBound..<html.endIndex) == nil else {
                throw BlockProcessingError.missingBody
            }
            html.replaceSubrange(range, with: replacement)
        }
        return BlockResult(html: html, diagnostics: diagnostics + processed.diagnostics)
    }

    private enum MathFragmentError: Error { case invalidOutput }

    private func processHTML(_ original: String) throws -> BlockResult {
        if renderers.isEmpty { return BlockResult(html: original, diagnostics: []) }
        let doc = try HTMLDocument.parseFragment(original)
        guard let body = doc.body else { throw BlockProcessingError.missingBody }
        var diagnostics: [BlockDiagnostic] = []
        var fragments: [(String, String)] = []
        for (index, code) in try body.select("pre > code").enumerated() {
            guard let pre = code.parent else { continue }
            let classes = try (code.attribute("class") ?? "").split(whereSeparator: { $0.isWhitespace })
            let preLanguage = try (pre.attribute("lang") ?? "").split(whereSeparator: { $0.isWhitespace }).first.map(String.init)
            let label = classes.first(where: { $0.hasPrefix("language-") }).map { String($0.dropFirst(9)) }
                ?? preLanguage ?? ""
            let language = label.lowercased()
            guard !language.isEmpty else { continue }
            guard let literal = code.directText() else {
                diagnostics.append(.init(kind: .unsupportedContent, blockIndex: index, language: language, message: "Code element contains non-text nodes"))
                continue
            }
            guard let renderer = renderers.first(where: { $0.accepts(language: language) }) else {
                diagnostics.append(.init(kind: .unsupportedLanguage, blockIndex: index, language: language, message: "No renderer accepts this language"))
                continue
            }
            do {
                switch try renderer.render(literal: literal, language: language, index: index) {
                case .codeHTML(let html): try code.setInnerHTML(html)
                case .blockHTML(let html): try pre.insertHTMLBefore(html); try pre.remove()
                case .validatedSVG(let svg):
                    var marker: String
                    repeat { marker = "SWIFTMD" + UUID().uuidString.replacingOccurrences(of: "-", with: "") } while original.contains(marker)
                    try pre.insertTextBefore(marker); try pre.remove()
                    fragments.append((marker, svg.html))
                }
            } catch {
                diagnostics.append(.init(kind: .renderFailed, blockIndex: index, language: language, message: String(describing: error)))
            }
        }
        var html = try body.innerHTML()
        for (marker, fragment) in fragments {
            guard let range = html.range(of: marker), html.range(of: marker, range: range.upperBound..<html.endIndex) == nil else { throw BlockProcessingError.missingBody }
            html.replaceSubrange(range, with: fragment)
        }
        return BlockResult(html: html, diagnostics: diagnostics)
    }
}
