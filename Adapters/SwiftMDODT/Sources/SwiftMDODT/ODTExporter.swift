// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftGFM

/// Sibling of the existing DOCX projection. The same bounded typed GFM
/// grammar feeds an independent ODF writer; never convert DOCX to ODT.
public struct ODTExporter: Sendable {
    public init() {}

    public func render(_ source: String, title: String, options: ODTOptions = .init(),
                       captures: [ODTRaster] = []) throws -> Data {
        let configuration = MarkdownConfiguration(extensions: .gfm, limits: .init(
            maximumInputUTF8Bytes: 1_048_576, maximumASTNodes: 50_000, maximumASTDepth: 64))
        let document = try MarkdownEngine(configuration: configuration).parse(source)
        var writer = try OpenDocumentWriter(options: options, captures: captures)
        return try writer.render(title: title, blocks: Self.blocks(document.root.children, depth: 0))
    }

    private static func blocks(_ nodes: [MarkdownNode], depth: Int) throws -> [ODTBlock] {
        guard depth <= 32 else { throw ODTError.invalidStructure }
        return try nodes.map { node in
            try Task.checkCancellation()
            switch node.kind {
            case .paragraph: return .paragraph(try inline(node.children, depth: 0))
            case .heading(let level): return .heading(level, try inline(node.children, depth: 0))
            case .blockQuote: return .quote(try blocks(node.children, depth: depth + 1))
            case .codeBlock(let literal, let info, _):
                let language = info.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
                let label = language.isEmpty ? "" : "[\(language) source]\n"
                return .code(label + literal)
            case .thematicBreak: return .rule
            case .list(let style, _):
                let marker: ODTListMarker
                switch style {
                case .bullet: marker = .bullet
                case .ordered(let start, let delimiter): marker = .ordered(start: start, parenthesis: delimiter == .parenthesis)
                }
                let items = try node.children.map { child -> ODTListItem in
                    let task: Bool?
                    switch child.kind {
                    case .listItem: task = nil
                    case .taskListItem(_, let checked): task = checked
                    default: throw ODTError.invalidStructure
                    }
                    return ODTListItem(task: task, blocks: try blocks(child.children, depth: depth + 1))
                }
                return .list(marker, items)
            case .table(let alignments):
                let columns: [ODTAlignment] = alignments.map {
                    switch $0 {
                    case .center: .center
                    case .right: .right
                    default: .left
                    }
                }
                let rows = try node.children.map { row -> ODTTableRow in
                    guard case .tableRow(let header) = row.kind else { throw ODTError.invalidStructure }
                    let cells = try row.children.map { cell -> [ODTInline] in
                        guard case .tableCell = cell.kind else { throw ODTError.invalidStructure }
                        return try inline(cell.children, depth: 0)
                    }
                    return ODTTableRow(header: header, cells: cells)
                }
                return .table(columns, rows)
            case .htmlBlock: throw ODTError.unsupported("raw HTML")
            case .footnoteDefinition: throw ODTError.unsupported("footnote")
            default: throw ODTError.unsupported("unhandled block node")
            }
        }
    }

    private static func inline(_ nodes: [MarkdownNode], depth: Int) throws -> [ODTInline] {
        guard depth <= 32 else { throw ODTError.invalidStructure }
        var output: [ODTInline] = []
        for node in nodes {
            try Task.checkCancellation()
            switch node.kind {
            case .text(let value): output.append(.text(value))
            case .softBreak: output.append(.text(" "))
            case .lineBreak: output.append(.lineBreak)
            case .code(let value): output.append(.span(.code, [.text(value)]))
            case .strong: output.append(.span(.bold, try inline(node.children, depth: depth + 1)))
            case .emphasis: output.append(.span(.italic, try inline(node.children, depth: depth + 1)))
            case .strikethrough: output.append(.span(.strike, try inline(node.children, depth: depth + 1)))
            case .link(let destination, let title):
                output += try inline(node.children, depth: depth + 1)
                // Match DOCX's explicit inert link policy; never create remote
                // relationships or request files on behalf of the document.
                output.append(.text(" (\(destination)\(title.isEmpty ? "" : " — " + title))"))
            case .image(let destination, let title):
                output.append(.image(destination: destination, alt: try altText(node.children, depth: depth + 1), title: title))
            case .htmlInline: throw ODTError.unsupported("raw inline HTML")
            case .footnoteReference: throw ODTError.unsupported("footnote")
            default: throw ODTError.unsupported("unhandled inline node")
            }
        }
        return output
    }

    private static func altText(_ nodes: [MarkdownNode], depth: Int) throws -> String {
        guard depth <= 32 else { throw ODTError.invalidStructure }
        var text = ""
        for node in nodes {
            switch node.kind {
            case .text(let value), .code(let value): text += value
            case .softBreak, .lineBreak: text += " "
            case .strong, .emphasis, .strikethrough, .link:
                text += try altText(node.children, depth: depth + 1)
            default: throw ODTError.unsupported("image alternative text")
            }
            guard text.utf8.count <= 4096 else { throw ODTError.imageBudget }
        }
        return text
    }
}
