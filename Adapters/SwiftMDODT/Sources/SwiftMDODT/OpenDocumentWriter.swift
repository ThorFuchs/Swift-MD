// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Small export-only ODF 1.4 text profile; no import/editing API.
public enum ODTError: LocalizedError, Equatable, Sendable {
    case unsupported(String), invalidText, invalidStructure, invalidOptions
    case invalidImage, imageBudget, missingImage(String), duplicateImage, unusedImage
    public var errorDescription: String? {
        switch self {
        case .unsupported(let detail): "Unsupported OpenDocument content: " + detail
        case .invalidText: "Text contains a forbidden XML 1.0 character."
        case .invalidStructure: "Invalid or excessive OpenDocument structure."
        case .invalidOptions: "Unsupported OpenDocument export settings."
        case .invalidImage: "Invalid or unsupported PNG/JPEG capture."
        case .imageBudget: "OpenDocument image budget exceeded."
        case .missingImage(let destination): "No explicit raster capture supplied for: " + destination
        case .duplicateImage: "Duplicate raster destination."
        case .unusedImage: "A raster capture does not belong to the exported source."
        }
    }
}

public struct ODTOptions: Sendable {
    public var letter: Bool
    public var bodyFontSize: Int
    public var headingPageBreak: Bool

    public init(letter: Bool = false, bodyFontSize: Int = 11, headingPageBreak: Bool = false) {
        self.letter = letter; self.bodyFontSize = bodyFontSize
        self.headingPageBreak = headingPageBreak
    }
}

enum ODTSpan: String, Sendable {
    case bold = "Bold", italic = "Italic", strike = "Strike", code = "InlineCode"
}

indirect enum ODTInline: Sendable {
    case text(String), span(ODTSpan, [ODTInline]), lineBreak
    case image(destination: String, alt: String, title: String)
}

enum ODTAlignment: String, Sendable {
    case left, center, right
}

enum ODTListMarker: Sendable {
    case bullet, ordered(start: Int, parenthesis: Bool)
}

struct ODTListItem: Sendable {
    let task: Bool?
    let blocks: [ODTBlock]
}

struct ODTTableRow: Sendable {
    let header: Bool
    let cells: [[ODTInline]]
}

indirect enum ODTBlock: Sendable {
    case paragraph([ODTInline])
    case heading(Int, [ODTInline])
    case quote([ODTBlock])
    case code(String)
    case list(ODTListMarker, [ODTListItem])
    case table([ODTAlignment], [ODTTableRow])
    case rule
}

/// The renderer accepts only typed content; all user strings are XML escaped.
/// Styles, element names and archive entry paths are owned by the exporter.
struct OpenDocumentWriter {
    static let mime = "application/vnd.oasis.opendocument.text"
    private static let header = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
    private static let namespaces = """
    xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0"
    xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0"
    xmlns:style="urn:oasis:names:tc:opendocument:xmlns:style:1.0"
    xmlns:fo="urn:oasis:names:tc:opendocument:xmlns:xsl-fo-compatible:1.0"
    xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0"
    xmlns:meta="urn:oasis:names:tc:opendocument:xmlns:meta:1.0"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:draw="urn:oasis:names:tc:opendocument:xmlns:drawing:1.0"
    xmlns:svg="urn:oasis:names:tc:opendocument:xmlns:svg-compatible:1.0"
    xmlns:xlink="http://www.w3.org/1999/xlink"
    office:version="1.4"
    """
    let options: ODTOptions
    private var tables = 0
    private var nodes = 0
    private var captures: [Data: ODTRaster] = [:]
    private var paths: [Data: String] = [:]
    private var pictures: [(path: String, raster: ODTRaster)] = []
    private var imageOccurrences = 0
    private var maxImageWidth = 5.5

    init(options: ODTOptions = .init(), captures: [ODTRaster] = []) throws {
        self.options = options
        guard captures.count <= 128 else { throw ODTError.imageBudget }
        var bytes = 0, pixels = 0
        for capture in captures {
            guard self.captures.updateValue(capture, forKey: Data(capture.destination.utf8)) == nil else {
                throw ODTError.duplicateImage
            }
            bytes += capture.bytes.count
            pixels += capture.pixelWidth * capture.pixelHeight
            guard bytes <= 48 * 1024 * 1024, pixels <= 64_000_000 else { throw ODTError.imageBudget }
        }
    }

    mutating func render(title: String, blocks: [ODTBlock]) throws -> Data {
        guard [10,11,12,14].contains(options.bodyFontSize) else { throw ODTError.invalidOptions }
        tables = 0; nodes = 0; paths = [:]; pictures = []; imageOccurrences = 0; maxImageWidth = 5.5
        let body = try renderBlocks(blocks, depth: 0, listDepth: 0, quoted: false)
        guard paths.count == captures.count else { throw ODTError.unusedImage }
        let content = Self.header + "<office:document-content \(Self.namespaces)><office:body><office:text>"
            + (body.isEmpty ? "<text:p/>" : body) + "</office:text></office:body></office:document-content>"
        let meta = try Self.header + "<office:document-meta \(Self.namespaces)><office:meta>"
            + "<dc:title>\(Self.escape(title))</dc:title><meta:generator>SwiftMDODT</meta:generator>"
            + "</office:meta></office:document-meta>"
        let imageManifest = pictures.map {
            "<manifest:file-entry manifest:full-path=\"\($0.path)\" manifest:media-type=\"\($0.raster.format.mime)\"/>"
        }.joined()
        let manifest = Self.header + """
        <manifest:manifest xmlns:manifest="urn:oasis:names:tc:opendocument:xmlns:manifest:1.0" manifest:version="1.4">
        <manifest:file-entry manifest:full-path="/" manifest:version="1.4" manifest:media-type="\(Self.mime)"/>
        <manifest:file-entry manifest:full-path="content.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="styles.xml" manifest:media-type="text/xml"/>
        <manifest:file-entry manifest:full-path="meta.xml" manifest:media-type="text/xml"/>
        \(imageManifest)</manifest:manifest>
        """
        return try StoredZIP.encode([
            ("mimetype", Data(Self.mime.utf8)), ("content.xml", Data(content.utf8)),
            ("styles.xml", Data(styles().utf8)), ("meta.xml", Data(meta.utf8)),
            ("META-INF/manifest.xml", Data(manifest.utf8))
        ] + pictures.map { ($0.path, $0.raster.bytes) })
    }

    private mutating func tick(_ depth: Int) throws {
        nodes += 1
        guard depth <= 32, nodes <= 50_000 else { throw ODTError.invalidStructure }
        try Task.checkCancellation()
    }

    private mutating func renderBlocks(_ blocks: [ODTBlock], depth: Int, listDepth: Int,
                                       quoted: Bool) throws -> String {
        var result = ""
        for block in blocks {
            try tick(depth)
            switch block {
            case .paragraph(let children):
                result += try paragraph(children, style: quoted ? "Quote" : "Body")
            case .heading(let level, let children):
                guard (1...6).contains(level) else { throw ODTError.invalidStructure }
                result += try "<text:h text:style-name=\"Heading\(level)\" text:outline-level=\"\(level)\">"
                    + renderInline(children, depth: 0) + "</text:h>"
            case .quote(let children):
                result += try renderBlocks(children, depth: depth + 1, listDepth: listDepth, quoted: true)
            case .code(let code):
                result += try paragraph([.text(code)], style: "Code")
            case .rule:
                result += "<text:p text:style-name=\"Rule\"/>"
            case .list(let marker, let items):
                guard listDepth < 10, !items.isEmpty else { throw ODTError.invalidStructure }
                let name: String
                let start: Int?
                switch marker {
                case .bullet: name = "Bullet"; start = nil
                case .ordered(let number, let parenthesis):
                    guard (0...999_999_999).contains(number) else { throw ODTError.invalidStructure }
                    name = parenthesis ? "NumberParen" : "NumberDot"; start = number
                }
                result += "<text:list text:style-name=\"\(name)\">"
                for (index, item) in items.enumerated() {
                    let startAttr = index == 0 ? (start.map { " text:start-value=\"\($0)\"" } ?? "") : ""
                    result += "<text:list-item\(startAttr)>"
                    var content = item.blocks
                    let prefix = item.task.map { [ODTInline.text($0 ? "☒ " : "☐ ")] } ?? []
                    if case .paragraph(let first)? = content.first {
                        content[0] = .paragraph(prefix + first)
                    } else {
                        content.insert(.paragraph(prefix), at: 0)
                    }
                    result += try renderBlocks(content, depth: depth + 1, listDepth: listDepth + 1, quoted: quoted)
                    result += "</text:list-item>"
                }
                result += "</text:list>"
            case .table(let columns, let rows):
                guard !columns.isEmpty, columns.count <= 64, !rows.isEmpty, rows.count <= 2048,
                      rows.allSatisfy({ $0.cells.count == columns.count }),
                      !rows.dropFirst().contains(where: \.header) else { throw ODTError.invalidStructure }
                tables += 1
                result += "<table:table table:name=\"Table\(tables)\"><table:table-column table:number-columns-repeated=\"\(columns.count)\"/>"
                for row in rows {
                    if row.header { result += "<table:table-header-rows>" }
                    result += "<table:table-row>"
                    for (column, cell) in zip(columns, row.cells) {
                        let name = (row.header ? "Header" : "Cell") + column.rawValue.capitalized
                        let oldWidth = maxImageWidth
                        maxImageWidth = min(oldWidth, 5.5 / Double(columns.count) * 0.9)
                        defer { maxImageWidth = oldWidth }
                        result += try "<table:table-cell table:style-name=\"GridCell\" office:value-type=\"string\">"
                            + paragraph(cell, style: name) + "</table:table-cell>"
                    }
                    result += "</table:table-row>"
                    if row.header { result += "</table:table-header-rows>" }
                }
                result += "</table:table>"
            }
            guard result.utf8.count <= 32 * 1024 * 1024 else { throw StoredZIP.Failure.tooLarge }
        }
        return result
    }

    private mutating func paragraph(_ children: [ODTInline], style: String) throws -> String {
        try "<text:p text:style-name=\"\(style)\">" + renderInline(children, depth: 0) + "</text:p>"
    }

    private mutating func renderInline(_ children: [ODTInline], depth: Int) throws -> String {
        var result = ""
        for child in children {
            try tick(depth)
            switch child {
            case .text(let value): result += try Self.text(value)
            case .span(let style, let nested):
                result += try "<text:span text:style-name=\"\(style.rawValue)\">"
                    + renderInline(nested, depth: depth + 1) + "</text:span>"
            case .lineBreak: result += "<text:line-break/>"
            case .image(let destination, let alt, let title):
                result += try image(destination: destination, alt: alt, title: title)
            }
        }
        return result
    }

    private mutating func image(destination: String, alt: String, title: String) throws -> String {
        let key = Data(destination.utf8)
        guard let raster = captures[key] else { throw ODTError.missingImage(destination) }
        imageOccurrences += 1
        guard imageOccurrences <= 4096 else { throw ODTError.imageBudget }
        let path: String
        if let existing = paths[key] {
            path = existing
        } else {
            path = "Pictures/" + String(format: "image-%04d", pictures.count + 1) + "." + raster.format.fileExtension
            paths[key] = path
            pictures.append((path, raster))
        }
        // Use stored pixel geometry, not arbitrary metadata DPI. Limit page
        // footprint without upscaling; embedded bytes remain exactly intact.
        let width = Double(raster.pixelWidth) / 96
        let height = Double(raster.pixelHeight) / 96
        let scale = min(1, maxImageWidth / width, 5 / height)
        func inches(_ value: Double) -> String {
            String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), max(0.001, value * scale)) + "in"
        }
        let label = try Self.escape(title)
        let description = try Self.escape(alt)
        return """
        <draw:frame draw:name="Image\(imageOccurrences)" text:anchor-type="as-char" svg:width="\(inches(width))" svg:height="\(inches(height))"><draw:image xlink:href="\(path)" xlink:type="simple" xlink:show="embed" xlink:actuate="onLoad" draw:mime-type="\(raster.format.mime)"/><svg:title>\(label)</svg:title><svg:desc>\(description)</svg:desc></draw:frame>
        """
    }

    static func escape(_ value: String) throws -> String {
        guard value.unicodeScalars.allSatisfy({
            let n = $0.value
            return n == 9 || n == 10 || n == 13 || (0x20...0xd7ff).contains(n)
                || (0xe000...0xfffd).contains(n) || (0x10000...0x10ffff).contains(n)
        }) else { throw ODTError.invalidText }
        return value.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// ODF explicit whitespace elements prevent a reader from collapsing
    /// significant spaces, tabs and newlines in code and inline text.
    private static func text(_ value: String) throws -> String {
        var result = "", chunk = "", spaces = 0
        func flushText() throws { if !chunk.isEmpty { result += try escape(chunk); chunk = "" } }
        func flushSpaces() {
            if spaces > 0 { result += "<text:s text:c=\"\(spaces)\"/>"; spaces = 0 }
        }
        for character in value {
            if character == " " {
                try flushText(); spaces += 1
            } else {
                flushSpaces()
                switch character {
                case "\t": try flushText(); result += "<text:tab/>"
                case "\n", "\r", "\r\n": try flushText(); result += "<text:line-break/>"
                default: chunk.append(character)
                }
            }
        }
        flushSpaces(); try flushText()
        return result
    }

    private func styles() -> String {
        let size = options.bodyFontSize
        var xml = Self.header + "<office:document-styles \(Self.namespaces)><office:styles>"
        xml += """
        <style:default-style style:family="paragraph"><style:paragraph-properties fo:margin-bottom="0.08in"/><style:text-properties fo:font-family="Liberation Serif" fo:font-size="\(size)pt"/></style:default-style>
        <style:style style:name="Body" style:family="paragraph"/>
        <style:style style:name="Quote" style:family="paragraph" style:parent-style-name="Body"><style:paragraph-properties fo:margin-left="0.3in"/><style:text-properties fo:font-style="italic"/></style:style>
        <style:style style:name="Code" style:family="paragraph" style:parent-style-name="Body"><style:text-properties fo:font-family="Liberation Mono" fo:font-size="\(size)pt"/></style:style>
        <style:style style:name="Rule" style:family="paragraph"><style:paragraph-properties fo:border-bottom="0.5pt solid #888888" fo:padding-bottom="0.08in"/></style:style>
        <style:style style:name="Bold" style:family="text"><style:text-properties fo:font-weight="bold"/></style:style>
        <style:style style:name="Italic" style:family="text"><style:text-properties fo:font-style="italic"/></style:style>
        <style:style style:name="Strike" style:family="text"><style:text-properties style:text-line-through-style="solid"/></style:style>
        <style:style style:name="InlineCode" style:family="text"><style:text-properties fo:font-family="Liberation Mono"/></style:style>
        <style:style style:name="GridCell" style:family="table-cell"><style:table-cell-properties fo:padding="0.07in" fo:border="0.5pt solid #aaaaaa"/></style:style>
        """
        for level in 1...6 {
            let pointSize = [20,17,15,13,12,11][level - 1] + size - 11
            let pageBreak = options.headingPageBreak ? " fo:break-before=\"page\"" : ""
            xml += "<style:style style:name=\"Heading\(level)\" style:family=\"paragraph\" style:parent-style-name=\"Body\" style:default-outline-level=\"\(level)\"><style:paragraph-properties fo:keep-with-next=\"always\" fo:margin-top=\"0.16in\"\(pageBreak)/><style:text-properties fo:font-weight=\"bold\" fo:font-size=\"\(pointSize)pt\"/></style:style>"
        }
        for alignment in ["left", "center", "right"] {
            for header in [false, true] {
                let name = (header ? "Header" : "Cell") + alignment.capitalized
                xml += "<style:style style:name=\"\(name)\" style:family=\"paragraph\" style:parent-style-name=\"Body\"><style:paragraph-properties fo:text-align=\"\(alignment)\"/>"
                if header { xml += "<style:text-properties fo:font-weight=\"bold\"/>" }
                xml += "</style:style>"
            }
        }
        for name in ["Bullet", "NumberDot", "NumberParen"] {
            xml += "<text:list-style style:name=\"\(name)\">"
            for level in 1...10 {
                let element = name == "Bullet" ? "bullet" : "number"
                let marker = name == "Bullet" ? "text:bullet-char=\"•\"" :
                    "style:num-format=\"1\" style:num-suffix=\"\(name == "NumberParen" ? ")" : ".")\""
                xml += "<text:list-level-style-\(element) text:level=\"\(level)\" \(marker)><style:list-level-properties text:space-before=\"\(Double(level) * 0.25)in\" text:min-label-width=\"0.2in\"/></text:list-level-style-\(element)>"
            }
            xml += "</text:list-style>"
        }
        let width = options.letter ? "8.5in" : "21cm"
        let height = options.letter ? "11in" : "29.7cm"
        return xml + """
        </office:styles><office:automatic-styles><style:page-layout style:name="PageLayout"><style:page-layout-properties fo:page-width="\(width)" fo:page-height="\(height)" style:print-orientation="portrait" fo:margin="1in"/></style:page-layout></office:automatic-styles><office:master-styles><style:master-page style:name="Standard" style:page-layout-name="PageLayout"/></office:master-styles></office:document-styles>
        """
    }
}
