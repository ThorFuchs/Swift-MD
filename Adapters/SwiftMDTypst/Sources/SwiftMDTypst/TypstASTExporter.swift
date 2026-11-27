// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftGFM

public enum TypstProjectionError: Error, Sendable, Equatable, CustomStringConvertible {
    case unsupported(String)
    case unsafeValue(String)
    case resourceBudget(String)
    case invalidStructure(String)
    public var description: String {
        switch self {
        case .unsupported(let message): "Unsupported Markdown to Typst feature: \(message)"
        case .unsafeValue(let message): "Unsafe Markdown to Typst value: \(message)"
        case .resourceBudget(let message): "Typst projection budget: \(message)"
        case .invalidStructure(let message): "Invalid Markdown AST: \(message)"
        }
    }
}

/// Snapshot-local IDs vm-0, vm-1, ... match the current ViewMarkdown DOM
/// outline strategy. These are not stable persistent IDs across source edits.
public struct TypstHeading: Sendable, Equatable {
    public let key: String
    public let level: Int
    public let title: String
    public let sourceRange: MarkdownSourceRange?
}

/// Strict export stays the default. A Reader may explicitly request
/// bounded, inert representations for specific unsupported AST nodes.
public enum TypstUnsupportedContentPolicy: Sendable, Equatable {
    case strict
    case readerPreview
}

/// Finite, source-independent degradation diagnostics. No diagnostic
/// contains arbitrary input, file paths, or executable content.
public enum TypstPreviewDegradation: String, Sendable, CaseIterable, Hashable {
    case linkAsText
    case imageAsPlaceholder
    case htmlAsText
    case taskListAsText
    case mermaidAsCode
    case mathAsCode
}

/// Optional consumer-owned semantic functions. The caller supplies the
/// named, trusted publication definitions; Markdown cannot select names.
/// Default strict and reader-preview byte output remain unchanged.
public enum TypstListProjection: Sendable, Equatable {
    case native
    case semanticItemHooks
}

/// An exact UTF-8 destination can select a consumer-owned image slot.
/// The adapter never emits a destination or loads image bytes.
public struct TypstImageProjection: Sendable, Equatable {
    fileprivate let slots: [Data: Int]

    public init(slots: [Data: Int] = [:]) throws {
        guard slots.count <= 4_096, slots.allSatisfy({ destination, slot in
            (1...4_096).contains(destination.count) && (0..<512).contains(slot)
        }) else { throw TypstProjectionError.resourceBudget("invalid image slots") }
        self.slots = slots
    }
}

public struct TypstASTDocument: Sendable {
    public let body: String
    public let headings: [TypstHeading]
    public let degradations: [TypstPreviewDegradation]
}

/// Strict SwiftGFM semantic AST to Typst source projection.
/// No HTML-to-Typst translation, no raw Typst from Markdown input.
/// The optional math renderer is trusted application code, not arbitrary input.
public struct TypstASTExporter: Sendable {
    public typealias TrustedMathRenderer = @Sendable (String) throws -> String
    public let maximumOutputUTF8Bytes: Int
    public let maximumNestingDepth: Int
    public let unsupportedContentPolicy: TypstUnsupportedContentPolicy
    public let listProjection: TypstListProjection
    public let imageProjection: TypstImageProjection?
    private let trustedMathRenderer: TrustedMathRenderer?

    public init(maximumOutputUTF8Bytes: Int = 2_000_000,
                maximumNestingDepth: Int = 32,
                unsupportedContentPolicy: TypstUnsupportedContentPolicy = .strict,
                listProjection: TypstListProjection = .native,
                trustedMathRenderer: TrustedMathRenderer? = nil,
                imageProjection: TypstImageProjection? = nil) {
        self.maximumOutputUTF8Bytes = maximumOutputUTF8Bytes
        self.maximumNestingDepth = maximumNestingDepth
        self.unsupportedContentPolicy = unsupportedContentPolicy
        self.listProjection = listProjection
        self.trustedMathRenderer = trustedMathRenderer
        self.imageProjection = imageProjection
    }

    public func render(_ markdown: String) throws -> TypstASTDocument {
        guard markdown.utf8.count <= 1_000_000 else {
            throw TypstProjectionError.resourceBudget("source exceeds 1 MB")
        }
        let config = MarkdownConfiguration(
            options: [.sourcePositions],
            limits: .init(maximumInputUTF8Bytes: 1_000_000,
                          maximumASTNodes: 80_000,
                          maximumASTDepth: max(2, maximumNestingDepth + 2))
        )
        return try render(MarkdownEngine(configuration: config).parse(markdown))
    }

    public func render(_ document: MarkdownDocument) throws -> TypstASTDocument {
        guard (1...128).contains(maximumNestingDepth),
              (1...16_000_000).contains(maximumOutputUTF8Bytes) else {
            throw TypstProjectionError.resourceBudget("invalid limits")
        }
        guard case .document = document.root.kind else {
            throw TypstProjectionError.invalidStructure("document root")
        }
        var writer = Writer(limit: maximumOutputUTF8Bytes,
                            depthLimit: maximumNestingDepth,
                            math: trustedMathRenderer,
                            policy: unsupportedContentPolicy,
                            listProjection: listProjection,
                            imageProjection: imageProjection)
        let result = try writer.blocks(document.root.children, depth: 0)
        guard result.utf8.count <= maximumOutputUTF8Bytes else {
            throw TypstProjectionError.resourceBudget("output bytes")
        }
        return TypstASTDocument(
            body: result, headings: writer.headings,
            degradations: TypstPreviewDegradation.allCases.filter {
                writer.degradations.contains($0)
            }
        )
    }
}

private struct Writer {
    let limit: Int
    let depthLimit: Int
    let math: TypstASTExporter.TrustedMathRenderer?
    let policy: TypstUnsupportedContentPolicy
    let listProjection: TypstListProjection
    let imageProjection: TypstImageProjection?
    var headings: [TypstHeading] = []
    var degradations: Set<TypstPreviewDegradation> = []
    // Snapshot-local preorder identity, not a persistent source ID.
    var nextListID = 0

    private let codeLanguages: Set<String> = [
        "swift", "json", "python", "javascript", "typescript", "html", "css",
        "xml", "bash", "sh", "c", "cpp", "rust", "go", "java", "yaml", "sql", "text"
    ]

    private func budget(_ source: String) throws -> String {
        guard source.utf8.count <= limit else {
            throw TypstProjectionError.resourceBudget("fragment exceeds limit")
        }
        return source
    }

    private func literal(_ text: String) throws -> String {
        var result = "\""
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0: throw TypstProjectionError.unsafeValue("NUL")
            case 0...8, 11...12, 14...31, 127:
                throw TypstProjectionError.unsafeValue("control character")
            case 34: result += "\\\""
            case 92: result += "\\\\"
            case 10: result += "\\n"
            case 13: result += "\\r"
            case 9: result += "\\t"
            default: result.unicodeScalars.append(scalar)
            }
        }
        result += "\""
        return try budget(result)
    }

    private mutating func inlineSequence(_ nodes: [MarkdownNode], depth: Int) throws -> String {
        guard depth <= depthLimit else { throw TypstProjectionError.resourceBudget("inline depth") }
        var result = ""
        for node in nodes {
            result += try inline(node, depth: depth)
            _ = try budget(result)
        }
        return result
    }

    mutating func blocks(_ nodes: [MarkdownNode], depth: Int) throws -> String {
        guard depth <= depthLimit else { throw TypstProjectionError.resourceBudget("block depth") }
        var sections: [String] = []
        var total = 0
        for node in nodes {
            let value: String
            switch node.kind {
            case .paragraph:
                value = "#par[\(try inlineSequence(node.children, depth: depth + 1))]"
            case .heading(let level):
                guard (1...6).contains(level) else { throw TypstProjectionError.invalidStructure("heading level") }
                let key = "vm-\(headings.count)"
                let title = try plainText(node.children, depth: depth + 1)
                let contents = try inlineSequence(node.children, depth: depth + 1)
                headings.append(.init(key: key, level: level, title: title, sourceRange: node.range))
                value = "#heading(level: \(level))[\(contents)] <\(key)>"
            case .blockQuote:
                value = "#quote(block: true, quotes: false)[\(try blocks(node.children, depth: depth + 1))]"
            case .list(let style, let tight):
                value = try list(node.children, style: style, tight: tight, depth: depth + 1)
            case .table(let alignments):
                value = try table(node.children, alignments: alignments, depth: depth + 1)
            case .codeBlock(let text, let info, _):
                let lang = info.split(whereSeparator: \.isWhitespace).first.map(String.init)?.lowercased() ?? ""
                if ["math", "tex", "latex"].contains(lang) {
                    if let math {
                        // Never swallow failures from the trusted converter,
                        // including its own security and resource checks.
                        let converted = try math(text)
                        guard converted.hasPrefix("$"), converted.hasSuffix("$") else {
                            throw TypstProjectionError.invalidStructure("math provider must return bounded Typst math")
                        }
                        value = try budget(converted)
                    } else {
                        guard policy == .readerPreview else {
                            throw TypstProjectionError.unsupported("math fence requires trusted converter")
                        }
                        degradations.insert(.mathAsCode)
                        value = "#raw(\(try literal(text)), block: true)"
                    }
                } else if lang == "mermaid" {
                    guard policy == .readerPreview else {
                        throw TypstProjectionError.unsupported("Mermaid requires validated SVG asset")
                    }
                    degradations.insert(.mermaidAsCode)
                    value = "#raw(\(try literal(text)), block: true)"
                } else {
                    let language = codeLanguages.contains(lang) ? ", lang: \(try literal(lang))" : ""
                    value = "#raw(\(try literal(text)), block: true\(language))"
                }
            case .thematicBreak:
                value = "#line(length: 100%)"
            case .htmlBlock(let html):
                guard policy == .readerPreview else {
                    throw TypstProjectionError.unsupported("raw HTML block")
                }
                degradations.insert(.htmlAsText)
                value = "#raw(\(try literal(html)), block: true)"
            case .customBlock:
                throw TypstProjectionError.unsupported("custom block")
            case .footnoteDefinition:
                throw TypstProjectionError.unsupported("uncorrelated footnote definition")
            default:
                throw TypstProjectionError.invalidStructure("unexpected block \(node.kind)")
            }
            sections.append(value)
            total += value.utf8.count + 2
            guard total <= limit else { throw TypstProjectionError.resourceBudget("output too large") }
        }
        return sections.joined(separator: "\n\n")
    }

    private mutating func list(
        _ nodes: [MarkdownNode], style: MarkdownListStyle,
        tight: Bool, depth: Int
    ) throws -> String {
        guard depth <= depthLimit else { throw TypstProjectionError.resourceBudget("list depth") }
        let head: String
        let semantic = listProjection == .semanticItemHooks
        let listID = nextListID
        if semantic { nextListID += 1 }
        switch style {
        case .bullet:
            head = (semantic ? "vm-bullet-list" : "list") + "(tight: \(tight ? "true" : "false")"
        case .ordered(let start, let delimiter):
            guard (1...1_000_000).contains(start) else {
                throw TypstProjectionError.unsupported("list start")
            }
            let numbering = delimiter == .period ? "1." : "1)"
            head = (semantic ? "vm-ordered-list" : "enum") +
                "(start: \(start), numbering: \(try literal(numbering)), tight: \(tight ? "true" : "false")"
        }
        var items: [String] = []
        for item in nodes {
            switch item.kind {
            case .listItem:
                let body = try blocks(item.children, depth: depth + 1)
                if semantic {
                    // Typed argument data, not markup inferred from text.
                    items.append("(checked: none, body: [\(body)])")
                } else { items.append("[\(body)]") }
            case .taskListItem(_, let checked):
                if semantic {
                    let body = try blocks(item.children, depth: depth + 1)
                    items.append("(checked: \(checked ? "true" : "false"), body: [\(body)])")
                    continue
                }
                guard policy == .readerPreview else {
                    throw TypstProjectionError.unsupported("task list or unknown list item")
                }
                degradations.insert(.taskListAsText)
                let marker = checked ? "[x] " : "[ ] "
                let children = item.children
                var rendered: String
                if let first = children.first, case .paragraph = first.kind {
                    let content = try inlineSequence(first.children, depth: depth + 2)
                    rendered = "#par[#text(\(try literal(marker)))\(content)]"
                    let rest = try blocks(Array(children.dropFirst()), depth: depth + 1)
                    if !rest.isEmpty { rendered += "\n\n" + rest }
                } else {
                    rendered = "#text(\(try literal(marker)))"
                    let rest = try blocks(children, depth: depth + 1)
                    if !rest.isEmpty { rendered += "\n\n" + rest }
                }
                items.append("[\(try budget(rendered))]")
            default:
                throw TypstProjectionError.unsupported("task list or unknown list item")
            }
        }
        let identity = semantic ? ", list-id: \(listID)" : ""
        return "#\(head)\(identity)\(items.map { ", " + $0 }.joined()))"
    }

    private mutating func table(
        _ rows: [MarkdownNode], alignments: [MarkdownTableAlignment], depth: Int
    ) throws -> String {
        let n = alignments.count
        guard (1...32).contains(n), rows.count <= 2_000 else {
            throw TypstProjectionError.resourceBudget("table size")
        }
        let a = alignments.map { align -> String in
            switch align { case .none, .left: "left"; case .center: "center"; case .right: "right" }
        }.joined(separator: ", ")
        var cells: [String] = []
        var hasHeader = false
        for (rowNumber, row) in rows.enumerated() {
            guard case .tableRow(let header) = row.kind, row.children.count == n else {
                throw TypstProjectionError.invalidStructure("nonrectangular table")
            }
            var values: [String] = []
            for cell in row.children {
                guard case .tableCell = cell.kind else {
                    throw TypstProjectionError.invalidStructure("unexpected table child")
                }
                values.append("[\(try inlineSequence(cell.children, depth: depth + 1))]")
            }
            if header {
                guard rowNumber == 0, !hasHeader else {
                    throw TypstProjectionError.invalidStructure("unexpected table header")
                }
                hasHeader = true
                cells.append("table.header(\(values.joined(separator: ", ")))")
            } else {
                cells.append(contentsOf: values)
            }
        }
        guard hasHeader else { throw TypstProjectionError.invalidStructure("missing header") }
        return "#table(columns: \(n), align: (\(a)), \(cells.joined(separator: ", ")))"
    }

    private func plainText(_ nodes: [MarkdownNode], depth: Int) throws -> String {
        guard depth <= depthLimit else { throw TypstProjectionError.resourceBudget("text depth") }
        var result = ""
        for node in nodes {
            switch node.kind {
            case .text(let s), .code(let s): result += s
            case .softBreak, .lineBreak: result += " "
            case .emphasis, .strong, .strikethrough:
                result += try plainText(node.children, depth: depth + 1)
            case .link(let target, _):
                if policy == .readerPreview, linkFailure(target) != nil, node.children.isEmpty {
                    result += "[Link]"
                } else {
                    result += try plainText(node.children, depth: depth + 1)
                }
            case .image where imageProjection != nil:
                let alt = try plainText(node.children, depth: depth + 1)
                result += alt.isEmpty ? "Image" : alt
            case .image where policy == .readerPreview:
                result += try imagePlaceholder(node, depth: depth + 1)
            case .htmlInline(let html) where policy == .readerPreview:
                result += html
            default: throw TypstProjectionError.unsupported("heading child \(node.kind)")
            }
        }
        return try budget(result.split(whereSeparator: \.isWhitespace).joined(separator: " "))
    }

    private func imagePlaceholder(_ node: MarkdownNode, depth: Int) throws -> String {
        let alt = try plainText(node.children, depth: depth)
        return try budget(alt.isEmpty ? "[Image not loaded]" : "[Image: \(alt)]")
    }

    private func linkFailure(_ target: String) -> TypstProjectionError? {
        guard let url = URLComponents(string: target),
              let scheme = url.scheme?.lowercased(),
              ["http", "https", "mailto"].contains(scheme),
              target.utf8.count <= 4_096,
              !target.unicodeScalars.contains(where: { $0.value <= 32 || $0.value == 127 }) else {
            return .unsupported("link URL requires safe absolute HTTP(S) or mailto")
        }
        if scheme != "mailto" {
            guard let host = url.host, !host.isEmpty,
                  url.user == nil, url.password == nil else {
                return .unsupported("link host or credentials")
            }
        }
        return nil
    }

    private mutating func inline(_ node: MarkdownNode, depth: Int) throws -> String {
        guard depth <= depthLimit else { throw TypstProjectionError.resourceBudget("inline depth") }
        switch node.kind {
        case .text(let text): return "#text(\(try literal(text)))"
        case .code(let text): return "#raw(\(try literal(text)), block: false)"
        case .softBreak: return "#text(\" \")"
        case .lineBreak: return "#linebreak()"
        case .strong: return "#strong[\(try inlineSequence(node.children, depth: depth + 1))]"
        case .emphasis: return "#emph[\(try inlineSequence(node.children, depth: depth + 1))]"
        case .strikethrough: return "#strike[\(try inlineSequence(node.children, depth: depth + 1))]"
        case .link(let target, _):
            if let failure = linkFailure(target) {
                guard policy == .readerPreview else { throw failure }
                degradations.insert(.linkAsText)
                // Keep formatted visible link text, not an active link or a
                // guessed relative target. The exact URL remains in Source.
                return node.children.isEmpty
                    ? "#text(\"[Link]\")"
                    : try inlineSequence(node.children, depth: depth + 1)
            }
            return "#link(\(try literal(target)))[\(try inlineSequence(node.children, depth: depth + 1))]"
        case .image(let destination, _):
            if let imageProjection {
                let alt = try literal(plainText(node.children, depth: depth + 1))
                if let slot = imageProjection.slots[Data(destination.utf8)] {
                    return "#vm-image(\(slot), alt: \(alt))"
                }
                degradations.insert(.imageAsPlaceholder)
                return "#vm-missing-image(\(alt))"
            }
            guard policy == .readerPreview else {
                throw TypstProjectionError.unsupported("image needs validated asset")
            }
            degradations.insert(.imageAsPlaceholder)
            return "#text(\(try literal(imagePlaceholder(node, depth: depth + 1))))"
        case .htmlInline(let html):
            guard policy == .readerPreview else {
                throw TypstProjectionError.unsupported("raw HTML inline")
            }
            degradations.insert(.htmlAsText)
            return "#text(\(try literal(html)))"
        case .customInline: throw TypstProjectionError.unsupported("custom inline")
        case .footnoteReference: throw TypstProjectionError.unsupported("uncorrelated footnote")
        default: throw TypstProjectionError.invalidStructure("unexpected inline \(node.kind)")
        }
    }
}
