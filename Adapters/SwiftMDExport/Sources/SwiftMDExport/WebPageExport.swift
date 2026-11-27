// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Packaging choices for one generated, offline web page. No fetching,
/// filesystem reads, browser capture, executable scripts or private APIs.
public enum WebPageExportEncoding: Sendable {
    case html, webArchive, mhtml, warc
}

public enum WebPageExportError: Error, Equatable, Sendable {
    case budget, invalidHTML
}

/// Synthetic locations identify resources INSIDE an archive, not a claim
/// that View Markdown acquired them from a website.
public struct WebPageExport: Sendable {
    public static let origin = "https://viewmarkdown.invalid/"
    public static let maximumOutputBytes = 64 * 1024 * 1024
    public static let maximumRasterBytes = 32 * 1024 * 1024
    public static let maximumRasters = 128

    public struct Raster: Sendable {
        public let index: Int
        public let isPNG: Bool
        public let bytes: Data
        public init(index: Int, isPNG: Bool, bytes: Data) { self.index = index; self.isPNG = isPNG; self.bytes = bytes }
        public var mediaType: String { isPNG ? "image/png" : "image/jpeg" }
        public var location: String {
            WebPageExport.origin + "assets/" + String(index) + (isPNG ? ".png" : ".jpg")
        }
        public var dataURL: String { "data:" + mediaType + ";base64," + bytes.base64EncodedString() }
    }

    /// Exact HTML for standalone export and for offline CONTENT preview.
    /// An archive preview does not certify the browser's archive decoder.
    public let standaloneHTML: Data
    private let archiveHTML: Data
    private let rasters: [Raster]
    public let unresolvedMediaCount: Int
    public let hasInertLinks: Bool
    public var rasterCount: Int { rasters.count }

    /// The existing hardened SwiftMD HTML renderer owns the external
    /// projection. It contains no captured raster resources.
    public init(externalHTML: Data) throws {
        try self.init(standaloneHTML: externalHTML, archiveHTML: externalHTML,
                      rasters: [], unresolvedMediaCount: 0, hasInertLinks: false)
    }

    /// Trusted caller supplies admitted HTML/CSS and matching resource mappings.
    /// This is a container encoder, not an HTML sanitizer or image decoder.
    public init(standaloneHTML: Data, archiveHTML: Data, rasters: [Raster],
         unresolvedMediaCount: Int, hasInertLinks: Bool) throws {
        guard standaloneHTML.count <= Self.maximumOutputBytes,
              archiveHTML.count <= Self.maximumOutputBytes,
              rasters.count <= Self.maximumRasters,
              rasters.reduce(0, { $0 + $1.bytes.count }) <= Self.maximumRasterBytes else {
            throw WebPageExportError.budget
        }
        guard String(data: standaloneHTML, encoding: .utf8) != nil,
              String(data: archiveHTML, encoding: .utf8) != nil else { throw WebPageExportError.invalidHTML }
        guard (0...4096).contains(unresolvedMediaCount),
              Set(rasters.map(\.index)).count == rasters.count,
              rasters.allSatisfy({ (1...Self.maximumRasters).contains($0.index) && !$0.bytes.isEmpty }) else {
            throw WebPageExportError.invalidHTML
        }
        self.standaloneHTML = standaloneHTML
        self.archiveHTML = archiveHTML
        self.rasters = rasters
        self.unresolvedMediaCount = unresolvedMediaCount
        self.hasInertLinks = hasInertLinks
    }

    public func encode(_ encoding: WebPageExportEncoding) throws -> Data {
        let result: Data
        switch encoding {
        case .html: result = standaloneHTML
        case .webArchive: result = try safariArchive()
        case .mhtml: result = try mimeArchive()
        case .warc: result = try warcArchive()
        }
        guard result.count <= Self.maximumOutputBytes else { throw WebPageExportError.budget }
        return result
    }

    private var mainLocation: String { Self.origin + "index.html" }

    /// Binary plist WebArchive resource schema, not the deprecated WebView
    /// API. Native Safari open/replay remains an independent acceptance gate.
    private func safariArchive() throws -> Data {
        let main: [String: Any] = [
            "WebResourceURL": mainLocation,
            "WebResourceMIMEType": "text/html",
            "WebResourceTextEncodingName": "UTF-8",
            "WebResourceFrameName": "",
            "WebResourceData": archiveHTML
        ]
        let assets: [[String: Any]] = rasters.map {
            ["WebResourceURL": $0.location,
             "WebResourceMIMEType": $0.mediaType,
             "WebResourceData": $0.bytes]
        }
        return try PropertyListSerialization.data(fromPropertyList: [
            "WebMainResource": main, "WebSubresources": assets,
            "WebSubframeArchives": [] as [Any]
        ], format: .binary, options: 0)
    }

    /// RFC 2557 multipart/related. First part is HTML, with unique absolute
    /// Content-Locations and base64 bodies. No user text in MIME headers.
    private func mimeArchive() throws -> Data {
        let boundary = "vm-" + UUID().uuidString.lowercased()
        var out = Data()
        func append(_ text: String) { out.append(contentsOf: text.utf8) }
        func part(_ bytes: Data, type: String, location: String) throws {
            try Task.checkCancellation()
            append("--\(boundary)\r\nContent-Type: \(type)\r\nContent-Transfer-Encoding: base64\r\nContent-Location: \(location)\r\n\r\n")
            append(bytes.base64EncodedString(options: [.lineLength76Characters, .endLineWithCarriageReturn, .endLineWithLineFeed]))
            append("\r\n")
            guard out.count <= Self.maximumOutputBytes else { throw WebPageExportError.budget }
        }
        append("MIME-Version: 1.0\r\nContent-Type: multipart/related;\r\n type=\"text/html\";\r\n boundary=\"\(boundary)\"\r\n\r\n")
        try part(archiveHTML, type: "text/html; charset=UTF-8", location: mainLocation)
        for raster in rasters { try part(raster.bytes, type: raster.mediaType, location: raster.location) }
        append("--\(boundary)--\r\n")
        return out
    }

    /// WARC 1.1 single generated-page resource package, NOT an HTTP capture.
    /// All record lengths are actual byte counts, including binary assets.
    private func warcArchive() throws -> Data {
        var out = Data()
        let date = ISO8601DateFormatter().string(from: Date())
        let infoID = "<urn:uuid:\(UUID().uuidString.lowercased())>"
        func record(type: String, id: String, location: String?, mediaType: String, body: Data) throws {
            try Task.checkCancellation()
            var fields = [
                "WARC/1.1", "WARC-Type: \(type)", "WARC-Record-ID: \(id)", "WARC-Date: \(date)"
            ]
            if let location {
                fields.append("WARC-Target-URI: \(location)")
                fields.append("WARC-Warcinfo-ID: \(infoID)")
            }
            fields.append("Content-Type: \(mediaType)")
            fields.append("Content-Length: \(body.count)")
            out.append(contentsOf: (fields.joined(separator: "\r\n") + "\r\n\r\n").utf8)
            out.append(body)
            out.append(contentsOf: "\r\n\r\n".utf8)
            guard out.count <= Self.maximumOutputBytes else { throw WebPageExportError.budget }
        }
        try record(type: "warcinfo", id: infoID, location: nil,
                   mediaType: "application/warc-fields",
                   body: Data("software: SwiftMDExport\r\ndescription: Generated static publication, not a network crawl\r\n".utf8))
        try record(type: "resource", id: "<urn:uuid:\(UUID().uuidString.lowercased())>",
                   location: mainLocation, mediaType: "text/html; charset=UTF-8", body: archiveHTML)
        for raster in rasters {
            try record(type: "resource", id: "<urn:uuid:\(UUID().uuidString.lowercased())>",
                       location: raster.location, mediaType: raster.mediaType, body: raster.bytes)
        }
        return out
    }
}
