// SPDX-License-Identifier: Apache-2.0
import Foundation
import Crypto

/// Internal EPUB-oriented model, not a claim that arbitrary input conforms to EPUB.
public enum PublicationError: Error, Equatable, Sendable {
    case invalidMetadata, invalidInventory, wrongOwner, integrity, invalidSource
    case invalidSpine, invalidBinding, unresolvedMedia, budget, unsupportedResource
}

public enum ResourceRole: String, Codable, Sendable {
    case markdown, xhtml, css, png, jpeg

    public var mediaType: String {
        switch self {
        case .markdown: "text/markdown"
        case .xhtml: "application/xhtml+xml"
        case .css: "text/css"
        case .png: "image/png"
        case .jpeg: "image/jpeg"
        }
    }

    /// Virtual OCF paths are generated from UUIDs, not imported filenames.
    public func path(for id: UUID) -> String {
        let name = id.uuidString.lowercased()
        switch self {
        case .markdown: return "source/\(name).md"
        case .xhtml: return "content/\(name).xhtml"
        case .css: return "styles/\(name).css"
        case .png: return "media/\(name).png"
        case .jpeg: return "media/\(name).jpg"
        }
    }

    var isImage: Bool { self == .png || self == .jpeg }
}

public struct ResourceDescriptor: Codable, Equatable, Sendable {
    public let id: UUID
    public let documentID: UUID
    public let role: ResourceRole
    public let byteCount: Int
    public let sha256: String
    public var path: String { role.path(for: id) }
    public var itemID: String { "r-" + id.uuidString.lowercased() }

    public init(id: UUID = UUID(), documentID: UUID, role: ResourceRole, bytes: Data) {
        self.id = id
        self.documentID = documentID
        self.role = role
        byteCount = bytes.count
        sha256 = Self.digest(bytes)
    }

    public static func digest(_ bytes: Data) -> String {
        SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}

public struct ResourceBlob: Sendable {
    public let id: UUID
    public let bytes: Data
    public init(id: UUID, bytes: Data) { self.id = id; self.bytes = bytes }
}

public enum MissingResourceReason: String, Codable, Sendable {
    case notSelected, missing, permissionRequired, unsafe, unsupported
}

public enum MediaResolution: Codable, Equatable, Sendable {
    case captured(UUID)
    case unresolved(MissingResourceReason)
}

/// The exact AST image destination. The string is metadata, never file access.
public struct MediaBinding: Codable, Equatable, Sendable {
    public let destination: String
    public let resolution: MediaResolution
    public init(destination: String, resolution: MediaResolution) {
        self.destination = destination; self.resolution = resolution
    }
}

public struct SpineEntry: Codable, Equatable, Sendable {
    public let resourceID: UUID
    public let title: String
    public init(resourceID: UUID, title: String) {
        self.resourceID = resourceID; self.title = title
    }
}

/// Snapshot-local semantic heading target. No promise of identity across source edits.
public struct NavigationEntry: Codable, Equatable, Sendable {
    public let resourceID: UUID
    public let fragment: String
    public let title: String
    public let level: Int

    public init(resourceID: UUID, fragment: String, title: String, level: Int) {
        self.resourceID = resourceID; self.fragment = fragment
        self.title = title; self.level = level
    }
}

/// One portable manifest. Resource payloads are persisted separately by UUID.
/// The first profile is one or more static XHTML chapters, CSS and raster images.
public struct PublicationManifest: Codable, Equatable, Sendable {
    public let formatVersion: Int
    public let documentID: UUID
    public let snapshotID: UUID
    public let title: String
    public let language: String
    public let modified: Date
    public let projectionVersion: String
    public let themeDigest: String?
    public let sourceID: UUID
    public let resources: [ResourceDescriptor]
    public let spine: [SpineEntry]
    public let media: [MediaBinding]
    public let navigation: [NavigationEntry]?

    public init(documentID: UUID, snapshotID: UUID = UUID(), title: String,
                language: String, modified: Date, projectionVersion: String, themeDigest: String? = nil,
                sourceID: UUID, resources: [ResourceDescriptor], spine: [SpineEntry],
                media: [MediaBinding], navigation: [NavigationEntry]? = nil) {
        formatVersion = 1
        self.documentID = documentID; self.snapshotID = snapshotID
        self.title = title; self.language = language; self.modified = modified
        self.projectionVersion = projectionVersion; self.themeDigest = themeDigest; self.sourceID = sourceID
        self.resources = resources; self.spine = spine; self.media = media; self.navigation = navigation
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

/// A complete, hydrated package. No I/O, renderer privileges, or persistence here.
/// Integrity verification does NOT sanitize XHTML/CSS or validate image codecs.
/// Only app-generated, separately vetted projection bytes may reach the writer.
public struct PublicationSnapshot: Sendable {
    public let manifest: PublicationManifest
    private let blobs: [UUID: Data]

    public init(manifest: PublicationManifest, blobs: [ResourceBlob]) throws {
        guard manifest.formatVersion == 1, XMLText.valid(manifest.title),
              !manifest.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !manifest.projectionVersion.isEmpty, manifest.projectionVersion.utf8.count <= 128,
              manifest.title.utf8.count <= 4096,
              manifest.language.range(of: "^[A-Za-z]{2,8}(-[A-Za-z0-9]{1,8})*$", options: .regularExpression) == manifest.language.startIndex..<manifest.language.endIndex,
              manifest.themeDigest.map({ $0.utf8.count == 64 && $0.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }) ?? true,
              manifest.modified.timeIntervalSince1970.isFinite else { throw PublicationError.invalidMetadata }
        guard (1...512).contains(manifest.resources.count), blobs.count == manifest.resources.count,
              manifest.media.count <= 4096 else { throw PublicationError.invalidInventory }
        var dataByID: [UUID: Data] = [:]
        for blob in blobs {
            guard dataByID.updateValue(blob.bytes, forKey: blob.id) == nil else {
                throw PublicationError.invalidInventory
            }
        }
        var descriptors: [UUID: ResourceDescriptor] = [:]
        var total = 0
        for resource in manifest.resources {
            guard resource.documentID == manifest.documentID else { throw PublicationError.wrongOwner }
            guard descriptors.updateValue(resource, forKey: resource.id) == nil,
                  let data = dataByID[resource.id] else { throw PublicationError.invalidInventory }
            guard data.count <= 16 * 1024 * 1024 else { throw PublicationError.budget }
            total += data.count
            guard total <= 64 * 1024 * 1024 else { throw PublicationError.budget }
            guard data.count == resource.byteCount, ResourceDescriptor.digest(data) == resource.sha256 else {
                throw PublicationError.integrity
            }
        }
        guard manifest.resources.filter({ $0.role == .markdown }).count == 1,
              descriptors[manifest.sourceID]?.role == .markdown,
              let source = dataByID[manifest.sourceID], source.count <= 1_000_000,
              String(data: source, encoding: .utf8) != nil else { throw PublicationError.invalidSource }
        let contentIDs = Set(manifest.resources.filter { $0.role == .xhtml }.map(\.id))
        let spineIDs = manifest.spine.map(\.resourceID)
        guard !spineIDs.isEmpty, Set(spineIDs) == contentIDs, Set(spineIDs).count == spineIDs.count,
              manifest.spine.allSatisfy({ XMLText.valid($0.title) && !$0.title.isEmpty && $0.title.utf8.count <= 4096 }) else {
            throw PublicationError.invalidSpine
        }
        // Optional additive field; old v1 manifests decode with nil navigation.
        // Only generated vm-N anchors are admitted by this profile.
        if let navigation = manifest.navigation {
            guard navigation.count <= 1024 else { throw PublicationError.budget }
            for (ordinal, entry) in navigation.enumerated() {
                guard contentIDs.contains(entry.resourceID), entry.fragment == "vm-" + String(ordinal),
                      (1...6).contains(entry.level), XMLText.valid(entry.title),
                      !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      entry.title.utf8.count <= 4096 else { throw PublicationError.invalidSpine }
            }
        }
        var destinations = Set<Data>()
        var captured = Set<UUID>()
        for binding in manifest.media {
            guard !binding.destination.isEmpty, binding.destination.utf8.count <= 4096,
                  destinations.insert(Data(binding.destination.utf8)).inserted else { throw PublicationError.invalidBinding }
            if case .captured(let id) = binding.resolution {
                guard descriptors[id]?.role.isImage == true else { throw PublicationError.invalidBinding }
                captured.insert(id)
            }
        }
        guard captured == Set(manifest.resources.filter { $0.role.isImage }.map(\.id)) else {
            throw PublicationError.invalidBinding
        }
        self.manifest = manifest
        self.blobs = dataByID
    }

    public func bytes(for id: UUID) -> Data? { blobs[id] }

    public var sourceBytes: Data { blobs[manifest.sourceID]! } // init establishes membership
    public var hasUnresolvedMedia: Bool {
        manifest.media.contains { if case .unresolved = $0.resolution { true } else { false } }
    }
}

enum XMLText {
    static func valid(_ value: String) -> Bool {
        value.unicodeScalars.allSatisfy { s in
            switch s.value {
            case 9, 10, 13, 0x20...0xD7FF, 0xE000...0xFFFD, 0x10000...0x10FFFF: true
            default: false
            }
        }
    }
    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
