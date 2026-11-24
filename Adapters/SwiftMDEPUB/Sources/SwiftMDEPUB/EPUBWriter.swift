// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Narrow L00 packaging proof. Input must be a trusted static XHTML projection,
/// with its references already rewritten to generated resource paths. This is
/// not the production Markdown compiler, a sanitizer, or a general ZIP library.
public enum EPUBWriter {
    public enum SourcePolicy: Sendable { case readingOnly, includeSource }
    public struct Entry: Sendable {
        public let path: String
        public let bytes: Data
        fileprivate init(_ path: String, _ bytes: Data) { self.path = path; self.bytes = bytes }
        fileprivate init(_ path: String, _ text: String) { self.init(path, Data(text.utf8)) }
    }

    public static func entries(_ snapshot: PublicationSnapshot,
                               sourcePolicy: SourcePolicy = .readingOnly) throws -> [Entry] {
        guard !snapshot.hasUnresolvedMedia else { throw PublicationError.unresolvedMedia }
        let m = snapshot.manifest
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        let container = xml + "<container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"EPUB/package.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"
        let title = XMLText.escape(m.title), language = XMLText.escape(m.language)
        let date = ISO8601DateFormatter().string(from: m.modified)
        // Metadata is explicit, not clock-dependent at packaging time.
        guard date.range(of: "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$", options: .regularExpression) != nil else {
            throw PublicationError.invalidMetadata
        }
        let items = m.resources.filter { $0.role != .markdown }.sorted { $0.path < $1.path }
        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var metadata = "<dc:identifier id=\"pub-id\">urn:uuid:\(m.documentID.uuidString.lowercased())</dc:identifier><dc:title>\(title)</dc:title><dc:language>\(language)</dc:language><meta property=\"dcterms:modified\">\(date)</meta>"
        if sourcePolicy == .includeSource {
            guard let source = m.resources.first(where: { $0.id == m.sourceID }) else { throw PublicationError.invalidSource }
            // Linked resources are outside the OPF manifest and spine.
            metadata += "<link rel=\"alternate\" href=\"\(source.path)\" media-type=\"text/markdown\"/><link rel=\"record\" href=\"source/publication.json\" media-type=\"application/json\"/>"
        }
        let manifest = items.map { "<item id=\"\($0.itemID)\" href=\"\($0.path)\" media-type=\"\($0.role.mediaType)\"/>" }.joined()
        var spine = "", toc = ""
        for entry in m.spine {
            guard let resource = byID[entry.resourceID] else { throw PublicationError.invalidSpine }
            spine += "<itemref idref=\"\(resource.itemID)\"/>"
            toc += "<li><a href=\"\(resource.path)\">\(XMLText.escape(entry.title))</a></li>"
        }
        if let headings = m.navigation, !headings.isEmpty {
            // Flat navigation in source order for L00B; levels remain in the manifest and XHTML.
            // The trusted compiler must establish that every target actually exists.
            toc = ""
            for heading in headings {
                guard let resource = byID[heading.resourceID] else { throw PublicationError.invalidSpine }
                toc += "<li><a href=\"\(resource.path)#\(heading.fragment)\">\(XMLText.escape(heading.title))</a></li>"
            }
        }
        let opf = xml + "<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\" unique-identifier=\"pub-id\" xml:lang=\"\(language)\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\(metadata)</metadata><manifest><item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/>\(manifest)</manifest><spine>\(spine)</spine></package>"
        let nav = xml + "<html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\" lang=\"\(language)\" xml:lang=\"\(language)\"><head><title>\(title)</title></head><body><nav epub:type=\"toc\" id=\"toc\"><h1>Contents</h1><ol>\(toc)</ol></nav></body></html>"
        var result = [Entry("mimetype", "application/epub+zip"), Entry("META-INF/container.xml", container), Entry("EPUB/package.opf", opf), Entry("EPUB/nav.xhtml", nav)]
        for resource in items {
            guard let bytes = snapshot.bytes(for: resource.id) else { throw PublicationError.invalidInventory }
            result.append(Entry("EPUB/" + resource.path, bytes))
        }
        if sourcePolicy == .includeSource, let source = m.resources.first(where: { $0.id == m.sourceID }) {
            result.append(Entry("EPUB/" + source.path, snapshot.sourceBytes))
            result.append(Entry("EPUB/source/publication.json", try m.encoded()))
        }
        return result
    }

    public static func write(_ snapshot: PublicationSnapshot,
                             sourcePolicy: SourcePolicy = .readingOnly) throws -> Data {
        try storeZIP(entries(snapshot, sourcePolicy: sourcePolicy))
    }

    /// Stored ZIP32, adapted from the existing RhoeLanguage-Spec zipStore design.
    /// OCF mimetype is first and uncompressed, no extras. No Process/temp tree.
    /// Narrow bounded output only; deliberately no general archive input API.
    private static func storeZIP(_ entries: [Entry]) throws -> Data {
        guard entries.count <= 520, entries.first?.path == "mimetype" else { throw PublicationError.budget }
        var output = Data(), directory = Data(), names = Set<String>()
        for entry in entries {
            let name = Data(entry.path.utf8), bytes = entry.bytes
            guard !name.isEmpty, name.count <= 255,
                  entry.path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  entry.path.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || [45, 46, 47, 95].contains($0) }),
                  names.insert(entry.path).inserted else { throw PublicationError.invalidInventory }
            guard bytes.count <= 64 * 1024 * 1024,
                  output.count + bytes.count + directory.count + 512 <= 80 * 1024 * 1024 else { throw PublicationError.budget }
            let size = UInt32(bytes.count), offset = UInt32(output.count), crc = crc32(bytes)
            let nameLength = UInt16(name.count)
            output.u32(0x04034b50); output.u16(20); output.u16(0x800); output.u16(0)
            output.u16(0); output.u16(33); output.u32(crc); output.u32(size); output.u32(size)
            output.u16(nameLength); output.u16(0); output.append(name); output.append(bytes)
            directory.u32(0x02014b50); directory.u16(20); directory.u16(20); directory.u16(0x800); directory.u16(0)
            directory.u16(0); directory.u16(33); directory.u32(crc); directory.u32(size); directory.u32(size)
            directory.u16(nameLength); directory.u16(0); directory.u16(0); directory.u16(0); directory.u16(0)
            directory.u32(0); directory.u32(offset); directory.append(name)
        }
        let centralOffset = UInt32(output.count), centralSize = UInt32(directory.count), count = UInt16(entries.count)
        output.append(directory)
        output.u32(0x06054b50); output.u16(0); output.u16(0); output.u16(count); output.u16(count)
        output.u32(centralSize); output.u32(centralOffset); output.u16(0)
        return output
    }

    private static let crcTable: [UInt32] = (0..<256).map { value in
        var c = UInt32(value)
        for _ in 0..<8 { c = c & 1 == 1 ? (c >> 1) ^ 0xedb88320 : c >> 1 }
        return c
    }

    private static func crc32(_ bytes: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in bytes { crc = (crc >> 8) ^ crcTable[Int((crc ^ UInt32(byte)) & 255)] }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func u16(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value)); append(UInt8(truncatingIfNeeded: value >> 8))
    }
    mutating func u32(_ value: UInt32) {
        u16(UInt16(truncatingIfNeeded: value)); u16(UInt16(truncatingIfNeeded: value >> 16))
    }
}
