// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftGFM

public enum CompilerError: Error, Equatable, Sendable {
    case invalidSource, invalidText, invalidStructure, unsupported(String)
    case unsafeLink, missingAnchor, duplicateCapture, unusedCapture, invalidCapture, budget
}

/// Only bytes supplied by the caller's trusted, already verified capture stage.
/// L00B has no file resolver, image decoder, network, or authority to read a URL.
/// The initial proof uses known PNG fixtures; production capture is a separate gate.
public struct CapturedRaster: Sendable {
    public let destination: String
    public let role: ResourceRole
    public let bytes: Data

    public init(destination: String, role: ResourceRole, bytes: Data) {
        self.destination = destination; self.role = role; self.bytes = bytes
    }
}

/// A strict static XHTML backend for the existing SwiftMD/SwiftGFM AST.
/// One chapter, generated CSS, no raw HTML, script, runtime renderer, or I/O.
public enum PublicationCompiler {
    public static func compile(source: Data, documentID: UUID, title: String,
                               language: String, modified: Date,
                               captures: [CapturedRaster] = []) throws -> PublicationSnapshot {
        guard source.count <= 1_000_000 else { throw CompilerError.budget }
        guard let decoded = String(data: source, encoding: .utf8), validXML(decoded) else {
            throw CompilerError.invalidSource
        }
        guard captures.count <= 500 else { throw CompilerError.budget }
        guard validXML(title), validXML(language), title.utf8.count <= 4096,
              language.utf8.count <= 128 else { throw CompilerError.invalidText }
        var supplied: [Data: CapturedRaster] = [:]
        var captureBytes = 0
        for capture in captures {
            guard !capture.destination.isEmpty, capture.destination.utf8.count <= 4096,
                  [.png, .jpeg].contains(capture.role), !capture.bytes.isEmpty,
                  capture.bytes.count <= 16 * 1024 * 1024 else { throw CompilerError.invalidCapture }
            captureBytes += capture.bytes.count
            guard captureBytes <= 60 * 1024 * 1024 else { throw CompilerError.budget }
            guard supplied.updateValue(capture, forKey: Data(capture.destination.utf8)) == nil else {
                throw CompilerError.duplicateCapture
            }
        }

        // Preserve exact source bytes in the snapshot, including any leading BOM.
        // Strip one leading BOM from the parser input only.
        let text = decoded.hasPrefix("\u{FEFF}") ? String(decoded.dropFirst()) : decoded
        let configuration = MarkdownConfiguration(extensions: .gfm, options: [.sourcePositions, .footnotes],
            limits: .init(maximumInputUTF8Bytes: 1_000_000, maximumASTNodes: 50_000, maximumASTDepth: 64))
        let document = try MarkdownEngine(configuration: configuration).parse(text)
        let sourceDescriptor = ResourceDescriptor(documentID: documentID, role: .markdown, bytes: source)
        let cssBytes = Data(styles.utf8)
        let css = ResourceDescriptor(documentID: documentID, role: .css, bytes: cssBytes)
        let chapterID = UUID()
        var renderer = Renderer(documentID: documentID, chapterID: chapterID, captures: supplied)
        try renderer.emit(document.root)
        guard renderer.usedCaptures.count == supplied.count else { throw CompilerError.unusedCapture }
        guard renderer.references.isSubset(of: Set(renderer.headings.map(\.fragment))) else {
            throw CompilerError.missingAnchor
        }

        let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
            + "<html xmlns=\"http://www.w3.org/1999/xhtml\" lang=\"\(try escape(language))\" xml:lang=\"\(try escape(language))\"><head><title>\(try escape(title))</title><link rel=\"stylesheet\" href=\"../\(css.path)\"/></head><body>"
        let xhtml = Data((header + renderer.output + "</body></html>").utf8)
        let chapter = ResourceDescriptor(id: chapterID, documentID: documentID, role: .xhtml, bytes: xhtml)
        let manifest = PublicationManifest(documentID: documentID, title: title, language: language,
            modified: modified, projectionVersion: "SwiftMDEPUB-static-xhtml-swiftgfm-1.1.0-v1",
            sourceID: sourceDescriptor.id, resources: [sourceDescriptor, css, chapter] + renderer.resources,
            spine: [SpineEntry(resourceID: chapterID, title: title)], media: renderer.bindings,
            navigation: renderer.headings)
        let blobs = [ResourceBlob(id: sourceDescriptor.id, bytes: source),
                     ResourceBlob(id: css.id, bytes: cssBytes),
                     ResourceBlob(id: chapter.id, bytes: xhtml)] + renderer.blobs
        return try PublicationSnapshot(manifest: manifest, blobs: blobs)
    }

    // Built-in, reflowable, user-agent friendly CSS. No URLs, fonts, scripts or arbitrary CSS input.
    private static let styles = """
    body { font-family: serif; line-height: 1.5; margin: 5%; }
    h1, h2, h3, h4, h5, h6 { line-height: 1.2; margin-top: 1.4em; }
    p { margin: 0.7em 0; }
    li { margin: 0.25em 0; }
    blockquote { border-left: 0.2em solid; padding-left: 1em; margin-left: 0; }
    pre { white-space: pre-wrap; overflow-wrap: break-word; border: 1px solid; padding: 0.6em; }
    code { font-family: monospace; }
    table { border-collapse: collapse; width: 100%; }
    th, td { border: 1px solid; padding: 0.35em; }
    th { font-weight: bold; }
    .left { text-align: left; } .center { text-align: center; } .right { text-align: right; }
    img { max-width: 100%; height: auto; }
    .missing { font-style: italic; }
    """
}

private func validXML(_ value: String) -> Bool {
    value.unicodeScalars.allSatisfy {
        switch $0.value {
        case 9, 10, 13, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
        default: false
        }
    }
}

private func escape(_ value: String) throws -> String {
    guard validXML(value) else { throw CompilerError.invalidText }
    return value.replacingOccurrences(of: "&", with: "&amp;")
        .replacingOccurrences(of: "<", with: "&lt;")
        .replacingOccurrences(of: ">", with: "&gt;")
        .replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "'", with: "&apos;")
}

private struct Renderer {
    let documentID: UUID
    let chapterID: UUID
    let captures: [Data: CapturedRaster]
    var output = ""
    var outputBytes = 0
    var headings: [NavigationEntry] = []
    var references: Set<String> = []
    var usedCaptures: Set<Data> = []
    var resources: [ResourceDescriptor] = []
    var blobs: [ResourceBlob] = []
    var bindings: [MediaBinding] = []
    var resolutions: [Data: MediaResolution] = [:]

    mutating func append(_ value: String) throws {
        outputBytes += value.utf8.count
        guard outputBytes <= 4 * 1024 * 1024 else { throw CompilerError.budget }
        output += value
    }

    mutating func children(_ node: MarkdownNode) throws {
        for child in node.children { try emit(child) }
    }

    mutating func wrap(_ tag: String, _ node: MarkdownNode) throws {
        try append("<\(tag)>")
        try children(node)
        try append("</\(tag)>")
    }

    func plain(_ node: MarkdownNode) throws -> String {
        var result = ""
        try node.walk { child in
            switch child.kind {
            case .text(let s), .code(let s): result += s
            case .softBreak, .lineBreak: result += " "
            case .htmlBlock, .htmlInline, .customInline, .customBlock, .footnoteDefinition, .footnoteReference:
                throw CompilerError.unsupported("raw/custom/footnote in text")
            default: break
            }
            guard result.utf8.count <= 4096 else { throw CompilerError.budget }
            return .visitChildren
        }
        guard validXML(result) else { throw CompilerError.invalidText }
        return result
    }

    mutating func emit(_ node: MarkdownNode) throws {
        switch node.kind {
        case .document: try children(node)
        case .paragraph: try wrap("p", node)
        case .blockQuote: try wrap("blockquote", node)
        case .heading(let level):
            guard (1...6).contains(level), headings.count < 1024 else { throw CompilerError.budget }
            let label = try plain(node)
            guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CompilerError.invalidStructure
            }
            let anchor = "vm-\(headings.count)"
            headings.append(NavigationEntry(resourceID: chapterID, fragment: anchor, title: label, level: level))
            try append("<h\(level) id=\"\(anchor)\">")
            try children(node)
            try append("</h\(level)>")
        case .text(let value): try append(escape(value))
        case .softBreak: try append("\n")
        case .lineBreak: try append("<br/>")
        case .thematicBreak: try append("<hr/>")
        case .emphasis: try wrap("em", node)
        case .strong: try wrap("strong", node)
        case .strikethrough: try wrap("s", node)
        case .code(let value): try append("<code>\(try escape(value))</code>")
        case .codeBlock(let value, let info, _):
            let language = info.split(whereSeparator: { $0.isWhitespace }).first?.lowercased() ?? ""
            guard !["math", "latex", "tex", "mermaid"].contains(language) else {
                throw CompilerError.unsupported("math/diagram fence")
            }
            try append("<pre><code>\(try escape(value))</code></pre>")
        case .list(let style, _):
            switch style {
            case .bullet: try wrap("ul", node)
            case .ordered(let start, _):
                guard start >= 0 else { throw CompilerError.invalidStructure }
                try append("<ol start=\"\(start)\">")
                try children(node)
                try append("</ol>")
            }
        case .listItem: try wrap("li", node)
        case .taskListItem:
            throw CompilerError.unsupported("task-list item")
        case .link(let destination, let title):
            let href = try link(destination)
            try append("<a href=\"\(try escape(href))\"\(try titleAttribute(title))>")
            try children(node)
            try append("</a>")
        case .image(let destination, let title):
            try image(node, destination: destination, title: title)
        case .table(let alignments):
            try table(node, alignments)
        case .tableRow, .tableCell: throw CompilerError.invalidStructure
        case .htmlBlock, .htmlInline, .customBlock, .customInline:
            throw CompilerError.unsupported("raw HTML/custom node")
        case .footnoteDefinition, .footnoteReference:
            throw CompilerError.unsupported("footnote")
        }
    }

    func titleAttribute(_ title: String) throws -> String {
        title.isEmpty ? "" : " title=\"\(try escape(title))\""
    }

    mutating func link(_ destination: String) throws -> String {
        guard destination.utf8.count <= 4096, !destination.isEmpty,
              destination.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value != 127 }),
              !destination.contains("\\") else { throw CompilerError.unsafeLink }
        if destination.hasPrefix("#") {
            let fragment = String(destination.dropFirst())
            guard fragment.hasPrefix("vm-") else { throw CompilerError.missingAnchor }
            references.insert(fragment)
            return destination
        }
        // External hyperlinks are user navigation only, not media or network requests.
        guard let parts = URLComponents(string: destination), parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil,
              let url = parts.url else { throw CompilerError.unsafeLink }
        return url.absoluteString
    }

    mutating func image(_ node: MarkdownNode, destination: String, title: String) throws {
        guard !destination.isEmpty, destination.utf8.count <= 4096 else { throw CompilerError.invalidCapture }
        let key = Data(destination.utf8)
        let resolution: MediaResolution
        if let existing = resolutions[key] {
            resolution = existing
        } else {
            guard bindings.count < 4096 else { throw CompilerError.budget }
            if let capture = captures[key] {
                let descriptor = ResourceDescriptor(documentID: documentID, role: capture.role, bytes: capture.bytes)
                resources.append(descriptor)
                blobs.append(ResourceBlob(id: descriptor.id, bytes: capture.bytes))
                usedCaptures.insert(key)
                resolution = .captured(descriptor.id)
            } else {
                resolution = .unresolved(.notSelected)
            }
            resolutions[key] = resolution
            bindings.append(MediaBinding(destination: destination, resolution: resolution))
        }
        let alt = try escape(plain(node))
        switch resolution {
        case .captured(let id):
            guard let descriptor = resources.first(where: { $0.id == id }) else { throw CompilerError.invalidStructure }
            try append("<img src=\"../\(descriptor.path)\" alt=\"\(alt)\"\(try titleAttribute(title))/>")
        case .unresolved:
            try append("<span class=\"missing\">[Image unavailable: \(alt)]</span>")
        }
    }

    mutating func table(_ node: MarkdownNode, _ alignments: [MarkdownTableAlignment]) throws {
        let rows = node.children
        guard !alignments.isEmpty, !rows.isEmpty, alignments.count <= 128 else { throw CompilerError.invalidStructure }
        try append("<table><thead>")
        for (index, row) in rows.enumerated() {
            guard case .tableRow(let header) = row.kind, header == (index == 0),
                  row.children.count == alignments.count else { throw CompilerError.invalidStructure }
            if index == 1 { try append("</thead><tbody>") }
            try append("<tr>")
            for (column, cell) in row.children.enumerated() {
                guard case .tableCell = cell.kind else { throw CompilerError.invalidStructure }
                let tag = header ? "th" : "td"
                let alignment: String
                switch alignments[column] {
                case .none: alignment = ""
                case .left: alignment = " class=\"left\""
                case .center: alignment = " class=\"center\""
                case .right: alignment = " class=\"right\""
                }
                try append("<\(tag)\(header ? " scope=\"col\"" : "")\(alignment)>")
                try children(cell)
                try append("</\(tag)>")
            }
            try append("</tr>")
        }
        try append(rows.count == 1 ? "</thead></table>" : "</tbody></table>")
    }
}
