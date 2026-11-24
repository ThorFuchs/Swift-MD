// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Explicit opt-in for sharing the original Markdown and portable resource manifest.
/// A source-inclusive publication can contain paths or text absent from its reading edition.
public enum EPUBExportProfile: Sendable {
    case reading
    case includingSource
}

/// In-memory, static Markdown to EPUB 3.3 candidate.
/// No I/O, network, resource discovery, script or runtime browser.
public struct EPUBExporter: Sendable {
    public init() {}

    /// Build an independently inspectable publication before writing the ZIP.
    public func compile(_ source: Data, documentID: UUID = UUID(), title: String,
                        language: String, modified: Date = Date(),
                        captures: [CapturedRaster] = []) throws -> PublicationSnapshot {
        try PublicationCompiler.compile(source: source, documentID: documentID,
            title: title, language: language, modified: modified, captures: captures)
    }

    /// Convenience path. Default export never includes the original source.
    public func render(_ source: Data, documentID: UUID = UUID(), title: String,
                       language: String, modified: Date = Date(),
                       captures: [CapturedRaster] = [],
                       profile: EPUBExportProfile = .reading) throws -> Data {
        let snapshot = try compile(source, documentID: documentID, title: title,
            language: language, modified: modified, captures: captures)
        return try render(snapshot, profile: profile)
    }

    /// Export an immutable trusted compiler snapshot. The low-level writer does
    /// not sanitize arbitrary externally assembled XHTML/CSS or decode images.
    public func render(_ snapshot: PublicationSnapshot,
                       profile: EPUBExportProfile = .reading) throws -> Data {
        switch profile {
        case .reading: return try EPUBWriter.write(snapshot, sourcePolicy: .readingOnly)
        case .includingSource: return try EPUBWriter.write(snapshot, sourcePolicy: .includeSource)
        }
    }
}
