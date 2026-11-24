// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import SwiftMDEPUB

struct Fixture {
    let manifest: PublicationManifest
    let blobs: [ResourceBlob]
    let source: Data

    init(foreignOwner: Bool = false, unresolved: Bool = false,
         duplicateBinding: Bool = false, duplicateSpine: Bool = false) {
        let owner = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
        func resource(_ role: ResourceRole, _ data: Data, owner id: UUID? = nil) -> (ResourceDescriptor, ResourceBlob) {
            let desc = ResourceDescriptor(documentID: id ?? owner, role: role, bytes: data)
            return (desc, ResourceBlob(id: desc.id, bytes: data))
        }
        source = Data([0xef, 0xbb, 0xbf]) + Data("# Research & notes\r\n\r\n![A](images/a.png)\r\n![B](images/b.png)\r\n".utf8)
        let md = resource(.markdown, source)
        let a = resource(.png, Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAFElEQVR4nGOsXDmbAQaYGJAAbg4AV8wBxZn9lGYAAAAASUVORK5CYII=")!, owner: foreignOwner ? UUID() : owner)
        let b = resource(.png, Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAFElEQVR4nGM0iUpkgAEmBiSAmwMAL4UA9+X9lLoAAAAASUVORK5CYII=")!)
        let css = resource(.css, Data("body { font-family: serif; } img { max-width: 100%; }".utf8))
        let body = """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" lang="en" xml:lang="en"><head><title>Research &amp; notes</title><link rel="stylesheet" href="../\(css.0.path)"/></head><body><h1>Research &amp; notes</h1><p><img src="../\(a.0.path)" alt="A"/></p><p><img src="../\(b.0.path)" alt="B"/></p></body></html>
        """
        let content = resource(.xhtml, Data(body.utf8))
        let resources = [md, a, b, css, content]
        var media = [MediaBinding(destination: "images/a.png", resolution: .captured(a.0.id)), MediaBinding(destination: "images/b.png", resolution: .captured(b.0.id))]
        if unresolved { media.append(MediaBinding(destination: "https://example.org/missing.png", resolution: .unresolved(.notSelected))) }
        if duplicateBinding { media.append(media[0]) }
        let spine = SpineEntry(resourceID: content.0.id, title: "Research & notes")
        manifest = PublicationManifest(documentID: owner, title: "Research & notes", language: "en", modified: Date(timeIntervalSince1970: 1_735_689_600), projectionVersion: "L00-trusted-fixture-1", sourceID: md.0.id, resources: resources.map { $0.0 }, spine: duplicateSpine ? [spine, spine] : [spine], media: media)
        blobs = resources.map { $0.1 }
    }

    func snapshot() throws -> PublicationSnapshot { try PublicationSnapshot(manifest: manifest, blobs: blobs) }
}

@Test func originalUTF8AndManifestRoundTrip() throws {
    let fixture = Fixture()
    let decoded = try JSONDecoder().decode(PublicationManifest.self, from: fixture.manifest.encoded())
    #expect(decoded == fixture.manifest)
    let snapshot = try PublicationSnapshot(manifest: decoded, blobs: fixture.blobs)
    #expect(snapshot.sourceBytes == fixture.source)
    #expect(ResourceDescriptor.digest(Data("abc".utf8)) == "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    #expect(snapshot.bytes(for: UUID()) == nil)
}

@Test func foreignOwnerAndDamagedOrMissingPayloadsAreRejected() throws {
    #expect(throws: PublicationError.wrongOwner) { _ = try Fixture(foreignOwner: true).snapshot() }
    let f = Fixture()
    #expect(throws: PublicationError.invalidInventory) { _ = try PublicationSnapshot(manifest: f.manifest, blobs: Array(f.blobs.dropLast())) }
    var damaged = f.blobs
    damaged[0] = ResourceBlob(id: damaged[0].id, bytes: Data(repeating: 1, count: damaged[0].bytes.count))
    #expect(throws: PublicationError.integrity) { _ = try PublicationSnapshot(manifest: f.manifest, blobs: damaged) }
    var duplicate = f.blobs
    duplicate[1] = duplicate[0]
    #expect(throws: PublicationError.invalidInventory) { _ = try PublicationSnapshot(manifest: f.manifest, blobs: duplicate) }
}

@Test func duplicateBindingsAndSpineRejected() throws {
    #expect(throws: PublicationError.invalidBinding) { _ = try Fixture(duplicateBinding: true).snapshot() }
    #expect(throws: PublicationError.invalidSpine) { _ = try Fixture(duplicateSpine: true).snapshot() }
}

@Test func unresolvedMediaIsExplicitAndStrictExportFails() throws {
    let snapshot = try Fixture(unresolved: true).snapshot()
    #expect(snapshot.hasUnresolvedMedia)
    #expect(throws: PublicationError.unresolvedMedia) { _ = try EPUBWriter.write(snapshot) }
}

@Test func readingExportAndSourceExportHaveDistinctInventories() throws {
    let f = Fixture(), snapshot = try f.snapshot()
    let standard = try EPUBWriter.entries(snapshot)
    let source = try EPUBWriter.entries(snapshot, sourcePolicy: .includeSource)
    #expect(standard.first?.path == "mimetype")
    #expect(standard.first?.bytes == Data("application/epub+zip".utf8))
    #expect(standard.count == 8)
    #expect(source.count == 10)
    #expect(!standard.contains { $0.path.hasPrefix("EPUB/source/") })
    let original = try #require(source.first { $0.path == "EPUB/" + ResourceRole.markdown.path(for: f.manifest.sourceID) })
    #expect(original.bytes == f.source)
    let package = try #require(source.first { $0.path == "EPUB/package.opf" })
    let text = try #require(String(data: package.bytes, encoding: .utf8))
    #expect(text.contains("Research &amp; notes"))
    #expect(text.contains("rel=\"alternate\""))
    #expect(text.contains("rel=\"record\""))
    #expect(!text.contains("<item id=\"r-\(f.manifest.sourceID.uuidString.lowercased())\""))
    let archive = try EPUBWriter.write(snapshot)
    #expect(archive.prefix(4) == Data([0x50, 0x4b, 3, 4]))
    #expect(try EPUBWriter.write(snapshot) == archive)
    // Optional developer-only evidence destination; ordinary tests write no output.
    if let root = ProcessInfo.processInfo.environment["SWIFTMDEPUB_CORE_TEST_OUTPUT"] {
        let dir = URL(fileURLWithPath: root, isDirectory: true)
        try archive.write(to: dir.appendingPathComponent("reading.epub"))
        try EPUBWriter.write(snapshot, sourcePolicy: .includeSource).write(to: dir.appendingPathComponent("source.epub"))
    }
}
