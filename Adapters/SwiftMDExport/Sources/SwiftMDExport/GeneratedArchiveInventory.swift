// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Inventory of our bounded, generated containers. Never extracts files or
/// follows paths/URLs. ZIP is deliberately the stored-only subset produced
/// by SwiftMDExport, EPUB, DOCX and ODT; no arbitrary archive reader.
public enum GeneratedArchiveKind: Sendable { case storedZIP, webArchive, mhtml, warc }

public struct GeneratedArchiveEntry: Identifiable, Equatable, Sendable {
    public let name: String
    public let byteCount: Int
    public let mediaType: String?
    public var id: String { name }
}

public struct GeneratedArchiveInventory: Equatable, Sendable {
    public let entries: [GeneratedArchiveEntry]
    public let validation: String

    public enum Failure: LocalizedError, Equatable, Sendable {
        case invalid, unsupported, budget
        public var errorDescription: String? {
            switch self {
            case .invalid: "The generated container inventory is inconsistent."
            case .unsupported: "The container uses features outside the generated-archive profile."
            case .budget: "The archive inspection exceeds its bounded input or entry limit."
            }
        }
    }

    public static func inspect(_ data: Data, kind: GeneratedArchiveKind) throws -> Self {
        guard data.count <= 64 * 1024 * 1024 else { throw Failure.budget }
        try Task.checkCancellation()
        switch kind {
        case .storedZIP: return try zip(data)
        case .webArchive: return try plist(data)
        case .mhtml: return try mime(data)
        case .warc: return try warc(data)
        }
    }

    private static func result(_ entries: [GeneratedArchiveEntry], _ validation: String) throws -> Self {
        guard !entries.isEmpty, entries.count <= 1024 else { throw Failure.budget }
        guard Set(entries.map(\.name)).count == entries.count else { throw Failure.invalid }
        return Self(entries: entries, validation: validation)
    }

    private static func safePath(_ name: String) -> Bool {
        !name.isEmpty && name.utf8.count <= 255
            && !name.contains("\\") && !name.contains(":")
            && name.unicodeScalars.allSatisfy { !CharacterSet.controlCharacters.contains($0) }
            && name.split(separator: "/", omittingEmptySubsequences: false)
                .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private static func zip(_ data: Data) throws -> Self {
        let bytes = Array(data)
        func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i+1]) << 8 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i+2) << 16 }
        guard bytes.count >= 22 else { throw Failure.invalid }
        let end = bytes.count - 22
        guard u32(end) == 0x06054b50, u16(end+4) == 0, u16(end+6) == 0,
              u16(end+8) == u16(end+10), u16(end+20) == 0 else { throw Failure.unsupported }
        let count = u16(end+10), start = u32(end+16), size = u32(end+12)
        guard count > 0, count <= 1024 else { throw Failure.budget }
        guard start <= end, size == end - start else { throw Failure.invalid }
        var cursor = start, local = 0
        var entries: [GeneratedArchiveEntry] = []
        for _ in 0..<count {
            try Task.checkCancellation()
            guard cursor <= end - 46, u32(cursor) == 0x02014b50 else { throw Failure.invalid }
            let flags = u16(cursor+8), method = u16(cursor+10), crc = u32(cursor+16)
            let stored = u32(cursor+20), length = u32(cursor+24), n = u16(cursor+28)
            guard (flags == 0 || flags == 0x0800), method == 0, stored == length,
                  u16(cursor+30) == 0, u16(cursor+32) == 0, u16(cursor+34) == 0 else {
                throw Failure.unsupported
            }
            guard n > 0, n <= 255, n <= end - cursor - 46,
                  u32(cursor+42) == local, local <= start - 30,
                  u32(local) == 0x04034b50,
                  u16(local+6) == flags, u16(local+8) == method, u32(local+14) == crc,
                  u32(local+18) == stored, u32(local+22) == length,
                  u16(local+26) == n, u16(local+28) == 0 else { throw Failure.invalid }
            let nameStart = local + 30
            guard n <= start - nameStart, length <= start - nameStart - n,
                  bytes[nameStart..<nameStart+n].elementsEqual(bytes[cursor+46..<cursor+46+n]),
                  let name = String(bytes: bytes[nameStart..<nameStart+n], encoding: .utf8),
                  safePath(name) else { throw Failure.invalid }
            let payload = nameStart + n
            var value: UInt32 = 0xffffffff
            for byte in bytes[payload..<payload+length] {
                value = (value >> 8) ^ crcTable[Int((value ^ UInt32(byte)) & 255)]
            }
            guard Int(~value) == crc else { throw Failure.invalid }
            entries.append(.init(name: name, byteCount: length, mediaType: nil))
            local = payload + length
            cursor += 46 + n
        }
        guard cursor == end, local == start else { throw Failure.invalid }
        return try result(entries, "Stored ZIP directory, local headers, byte counts and CRC-32 verified. Not format/schema conformance.")
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = (value >> 1) ^ ((value & 1) == 1 ? 0xedb88320 : 0) }
        return value
    }

    private static func webName(_ location: String) throws -> String {
        guard location.hasPrefix(WebPageExport.origin), location.utf8.count <= 256 else {
            throw Failure.invalid
        }
        let name = String(location.dropFirst(WebPageExport.origin.count))
        guard safePath(name) else { throw Failure.invalid }
        return name
    }

    private static func plist(_ data: Data) throws -> Self {
        guard data.prefix(8).elementsEqual("bplist00".utf8),
              let root = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let main = root["WebMainResource"] as? [String: Any],
              let assets = root["WebSubresources"] as? [[String: Any]],
              assets.count <= 128, (root["WebSubframeArchives"] as? [Any])?.isEmpty == true else {
            throw Failure.invalid
        }
        let entries = try ([main] + assets).map { item -> GeneratedArchiveEntry in
            guard let location = item["WebResourceURL"] as? String,
                  let type = item["WebResourceMIMEType"] as? String,
                  let body = item["WebResourceData"] as? Data else { throw Failure.invalid }
            return .init(name: try webName(location), byteCount: body.count, mediaType: type)
        }
        return try result(entries, "Binary plist resource inventory and exact payload lengths. Browser replay not validated.")
    }

    private static let separator = Data("\r\n\r\n".utf8)

    private static func header(_ data: Data, from start: Int) throws -> (String, Int) {
        guard start >= 0, start <= data.count else { throw Failure.invalid }
        let limit = min(data.count, start + 8192)
        guard let range = data.range(of: separator, in: start..<limit),
              let value = String(data: data[start..<range.lowerBound], encoding: .utf8) else {
            throw Failure.invalid
        }
        return (value, range.upperBound)
    }

    private static func fields(_ lines: [String]) throws -> [String: String] {
        var values: [String: String] = [:]
        for line in lines {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { throw Failure.invalid }
            let key = parts[0].lowercased()
            guard values[key] == nil else { throw Failure.invalid }
            values[key] = parts[1].trimmingCharacters(in: .whitespaces)
        }
        return values
    }

    private static func mime(_ original: Data) throws -> Self {
        let data = Data(original)
        let (top, start) = try header(data, from: 0)
        let lines = top.components(separatedBy: "\r\n")
        guard lines.count == 4, lines[0] == "MIME-Version: 1.0",
              lines[1] == "Content-Type: multipart/related;", lines[2] == " type=\"text/html\";",
              lines[3].hasPrefix(" boundary=\""), lines[3].hasSuffix("\"") else { throw Failure.unsupported }
        let boundary = String(lines[3].dropFirst(11).dropLast())
        guard boundary.hasPrefix("vm-"), boundary.utf8.count == 39,
              UUID(uuidString: String(boundary.dropFirst(3))) != nil else { throw Failure.invalid }
        let marker = Data(("--" + boundary).utf8)
        let next = Data(("\r\n--" + boundary).utf8)
        var cursor = start, entries: [GeneratedArchiveEntry] = []
        while cursor < data.count {
            try Task.checkCancellation()
            guard marker.count <= data.count - cursor, data[cursor..<cursor+marker.count] == marker else {
                throw Failure.invalid
            }
            cursor += marker.count
            if data.count - cursor == 4 && data[cursor...] == Data("--\r\n".utf8) {
                return try result(entries, "Generated MIME boundaries, resource locations and decoded base64 payload lengths. Replay not validated.")
            }
            guard cursor <= data.count - 2, data[cursor..<cursor+2] == Data("\r\n".utf8),
                  entries.count < 129 else { throw Failure.invalid }
            let (h, body) = try header(data, from: cursor+2)
            let f = try fields(h.components(separatedBy: "\r\n"))
            guard f["content-transfer-encoding"] == "base64",
                  let location = f["content-location"], let type = f["content-type"],
                  let delimiter = data.range(of: next, in: body..<data.count) else { throw Failure.invalid }
            let encoded = data[body..<delimiter.lowerBound].filter { $0 != 13 && $0 != 10 }
            guard let decoded = Data(base64Encoded: Data(encoded)) else { throw Failure.invalid }
            entries.append(.init(name: try webName(location), byteCount: decoded.count, mediaType: type))
            cursor = delimiter.lowerBound + 2
        }
        throw Failure.invalid
    }

    private static func warc(_ original: Data) throws -> Self {
        let data = Data(original)
        var cursor = 0, entries: [GeneratedArchiveEntry] = [], ids = Set<String>()
        var infoID: String?
        while cursor < data.count {
            try Task.checkCancellation()
            guard entries.count < 130 else { throw Failure.budget }
            let (h, body) = try header(data, from: cursor)
            let lines = h.components(separatedBy: "\r\n")
            guard lines.first == "WARC/1.1" else { throw Failure.unsupported }
            let f = try fields(Array(lines.dropFirst()))
            guard let id = f["warc-record-id"], ids.insert(id).inserted,
                  let type = f["content-type"], let raw = f["content-length"],
                  let n = Int(raw), n >= 0, n <= data.count - body,
                  data.count - body - n >= 4,
                  data[body+n..<body+n+4] == separator else { throw Failure.invalid }
            let name: String
            if entries.isEmpty {
                guard f["warc-type"] == "warcinfo" else { throw Failure.invalid }
                infoID = id
                name = "WARC info"
            } else {
                guard f["warc-type"] == "resource", f["warc-warcinfo-id"] == infoID,
                      let location = f["warc-target-uri"] else { throw Failure.invalid }
                name = try webName(location)
            }
            entries.append(.init(name: name, byteCount: n, mediaType: type))
            cursor = body+n+4
        }
        return try result(entries, "WARC record lengths, unique IDs and resource references verified. Not a network capture or replay validation.")
    }
}
