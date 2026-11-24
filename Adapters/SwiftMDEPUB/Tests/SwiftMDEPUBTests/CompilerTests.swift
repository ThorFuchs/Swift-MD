// SPDX-License-Identifier: Apache-2.0
import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import Testing
@testable import SwiftMDEPUB

private let owner = UUID(uuidString: "12345678-1234-1234-1234-123456789abc")!
private let date = Date(timeIntervalSince1970: 1_735_689_600)
private let pngA = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAUAAAABwCAIAAADg/z7kAAABt0lEQVR42u3cvQ3CMBCAUSfKGBmLkpqWAagZgJZpKSLRcubHugvv1ZAi0scZcDyth2MDaprdAhAwIGBAwCBgQMCAgAEBg4CBHJbeN9yvZ3cNfuR0uXW9fopvpZQuZMs4GvCz3t5PCOCNFW4wtFDA20WlCyMzjhQ3qxdyLqEjX1r9Cg2FzcYv1B3CJjDsdwIDAgYEDAgYBAwIGPjA8q0L/fOjDl3/k3smhC9urDCBwRIaEDAgYBAwIGBAwICAQcCAgAEBg4CBiha3YDAnBGICAwIGAQMCBgQMAgYEDAgYEDAIGEjEVsrRnAtdQpUdryYwWEIDAgYEDAIGBAwIGBAwCBgQMCBgEDBQkYcZRnMuNCYwIGAQMCBgQMAgYEDAgIABAYOAgURspRzNudAfshfVBAYBAwIGBAwCBgQMCBgQMAgYEDAgYEDAUJ2HGUazFx8TGBAwWEJbGYIJDAgYBAwIGBAwIGAQMFAn4O3fXUcZw2BbdC+3V5jAsOsltCEMOcdva21aD8f4FZstk/D7dOOhRQM2hGGY+JjsCFjGkCfdNwMG8vArNAgYEDAgYBAwIGBAwICAQcBAEg94f08RHMuCzAAAAABJRU5ErkJggg==")!
private let pngB = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAUAAAABwCAIAAADg/z7kAAABtklEQVR42u3csQ3CMBBAUSfKVlmDIdIxCx0SKzAkRSRazhCsO3ivhhSRPmfA8XTb1gbUNLsFIGBAwICAQcCAgAEBAwIGAQM5LL1vOJ03dw2+5H65dr1+im+llC5kyzga8LPe3k8I4I0VbjC0UMD7RaULIzOOFDerF3IuoSNfWv0KDYXNxi/UHcImMPzuBAYEDAgYEDAIGBAw8IHlqAv986MOXf+TeyaEAzdWmMBgCQ0IGBAwCBgQMCBgQMAgYEDAgIBBwEBFi1swmBMCMYEBAYOAAQEDAgYBAwIGBAwIGAQMJGIr5WjOhS6hyo5XExgsoQEBAwIGAQMCBgQMCBgEDAgYEDAIGKjIwwyjORcaExgQMAgYEDAgYBAwIGBAwICAQcBAIrZSjuZc6A/Zi2oCg4ABAQMCBgEDAgYEDAgYBAwIGBAwIGCozsMMo9mLjwkMCBgsoa0MwQQGBAwCBgQMCBgQMAgYqBPw/u+uo4xhsD26l9srTGD46SW0IQw5x29rbbpta/yKzZZJ+H668dCiARvCMEx8THYELGPIk+6bAQN5+BUaBAwIGBAwCBgQMCBgQMAgYCCJB91EVC0ebSWRAAAAAElFTkSuQmCC")!

private func compile(_ text: String, captures: [CapturedRaster] = []) throws -> PublicationSnapshot {
    try PublicationCompiler.compile(source: Data(text.utf8), documentID: owner,
        title: "Glass & Paper", language: "en", modified: date, captures: captures)
}

private func xhtml(_ snapshot: PublicationSnapshot) throws -> String {
    let id = try #require(snapshot.manifest.spine.first?.resourceID)
    let bytes = try #require(snapshot.bytes(for: id))
    let parser = XMLParser(data: bytes)
    parser.shouldProcessNamespaces = true
    parser.shouldResolveExternalEntities = false
    #expect(parser.parse())
    return try #require(String(data: bytes, encoding: .utf8))
}

@Test func realMarkdownReferencePublication() throws {
    let url = try #require(Bundle.module.url(forResource: "Reference", withExtension: "md", subdirectory: "Fixtures"))
    let original = try Data(contentsOf: url)
    let a = CapturedRaster(destination: "images/petrol.png", role: .png, bytes: pngA)
    let b = CapturedRaster(destination: "images/ochre.png", role: .png, bytes: pngB)
    let snapshot = try PublicationCompiler.compile(source: original, documentID: owner,
        title: "The living publication", language: "en", modified: date, captures: [a, b])
    let html = try xhtml(snapshot)
    #expect(snapshot.sourceBytes == original)
    #expect(snapshot.manifest.navigation?.map(\.fragment) == ["vm-0", "vm-1", "vm-2", "vm-3"])
    #expect(snapshot.manifest.navigation?.map(\.level) == [1, 2, 2, 2])
    #expect(html.contains("<strong>original source</strong>"))
    #expect(html.contains("<em>emphasis</em>"))
    #expect(html.contains("<s>a correction</s>"))
    #expect(html.contains("5 &lt; 7 &amp; 9 &gt; 3"))
    #expect(html.contains("<ol start=\"3\">"))
    #expect(html.contains("<blockquote>"))
    #expect(html.contains("<thead>") && html.contains("<tbody>"))
    #expect(html.contains("scope=\"col\" class=\"right\""))
    #expect(html.contains("<pre><code>") && html.contains("Glass &amp; Paper"))
    #expect(html.contains("href=\"#vm-2\""))
    #expect(snapshot.manifest.media.count == 2)
    #expect(snapshot.manifest.resources.filter { $0.role == .png }.count == 2)
    let images = snapshot.manifest.resources.filter { $0.role == .png }
    let first = try #require(images.first)
    #expect(html.components(separatedBy: "../" + first.path).count == 3)
    let reading = try EPUBWriter.entries(snapshot)
    let nav = try #require(reading.first { $0.path == "EPUB/nav.xhtml" })
    let navigation = try #require(String(data: nav.bytes, encoding: .utf8))
    #expect(navigation.contains("#vm-2") && navigation.contains("Evidence and observations"))
    #expect(!reading.contains { $0.path.hasPrefix("EPUB/source/") })
    let withSource = try EPUBWriter.entries(snapshot, sourcePolicy: .includeSource)
    #expect(withSource.contains { $0.path.hasSuffix(".md") && $0.bytes == original })
    if let path = ProcessInfo.processInfo.environment["SWIFTMDEPUB_TEST_OUTPUT"] {
        let root = URL(fileURLWithPath: path, isDirectory: true)
        try EPUBWriter.write(snapshot).write(to: root.appendingPathComponent("reference-reading.epub"))
        try EPUBWriter.write(snapshot, sourcePolicy: .includeSource).write(to: root.appendingPathComponent("reference-source.epub"))
    }
}

@Test func sourceBytesAndHeadingIdentity() throws {
    let source = Data([0xef, 0xbb, 0xbf]) + Data("# Same\r\n\r\n## Same\r\n\r\n[back](#vm-0)\r\n".utf8)
    let snapshot = try PublicationCompiler.compile(source: source, documentID: owner,
        title: "Same", language: "en", modified: date)
    #expect(snapshot.sourceBytes == source)
    #expect(snapshot.manifest.navigation?.map(\.fragment) == ["vm-0", "vm-1"])
    #expect(try xhtml(snapshot).contains("id=\"vm-1\""))
    let restored = try JSONDecoder().decode(PublicationManifest.self, from: snapshot.manifest.encoded())
    #expect(restored == snapshot.manifest)
}

@Test func missingMediaNeverLoadsAndBlocksStrictExport() throws {
    let snapshot = try compile("![local](../secret.png)\n\n![remote](https://example.org/photo.png)")
    #expect(snapshot.manifest.media.count == 2)
    #expect(snapshot.hasUnresolvedMedia)
    let html = try xhtml(snapshot)
    #expect(html.contains("Image unavailable: local"))
    #expect(!html.contains("src=") && !html.contains("secret.png") && !html.contains("example.org"))
    #expect(throws: PublicationError.unresolvedMedia) { _ = try EPUBWriter.write(snapshot) }
}

@Test func dangerousOrUnsupportedConstructsFailClosed() throws {
    #expect(throws: CompilerError.unsupported("raw HTML/custom node")) { _ = try compile("<script>alert(1)</script>") }
    #expect(throws: CompilerError.unsafeLink) { _ = try compile("[bad](javascript:alert)") }
    #expect(throws: CompilerError.unsafeLink) { _ = try compile("[bad](file:///etc/passwd)") }
    #expect(throws: CompilerError.unsafeLink) { _ = try compile("[bad](../other.md)") }
    #expect(throws: CompilerError.missingAnchor) { _ = try compile("[bad](#vm-9)") }
    #expect(throws: CompilerError.unsupported("math/diagram fence")) { _ = try compile("~~~mermaid\nA --> B\n~~~") }
    #expect(throws: CompilerError.unsupported("math/diagram fence")) { _ = try compile("~~~math\nx^2\n~~~") }
    #expect(throws: CompilerError.unsupported("task-list item")) { _ = try compile("- [x] Done") }
    let literal = try compile("~~~html\n<script>inert</script>\n~~~")
    #expect(try xhtml(literal).contains("&lt;script&gt;inert&lt;/script&gt;"))
}

@Test func captureAdmissionAndEmptyNavigation() throws {
    let a = CapturedRaster(destination: "a.png", role: .png, bytes: pngA)
    #expect(throws: CompilerError.duplicateCapture) { _ = try compile("![a](a.png)", captures: [a, a]) }
    #expect(throws: CompilerError.unusedCapture) { _ = try compile("No image.", captures: [a]) }
    let invalid = CapturedRaster(destination: "a.png", role: .css, bytes: pngA)
    #expect(throws: CompilerError.invalidCapture) { _ = try compile("![a](a.png)", captures: [invalid]) }
    let snapshot = try compile("A document without headings.")
    #expect(snapshot.manifest.navigation == [])
    let entries = try EPUBWriter.entries(snapshot)
    let nav = try #require(entries.first { $0.path == "EPUB/nav.xhtml" })
    #expect(String(decoding: nav.bytes, as: UTF8.self).contains("Glass &amp; Paper"))
}

@Test func oldManifestWithoutNavigationStillDecodes() throws {
    let snapshot = try compile("# Heading")
    var json = try #require(JSONSerialization.jsonObject(with: snapshot.manifest.encoded()) as? [String: Any])
    json.removeValue(forKey: "navigation")
    let restored = try JSONDecoder().decode(PublicationManifest.self,
        from: JSONSerialization.data(withJSONObject: json))
    #expect(restored.navigation == nil)
    let blobs = try restored.resources.map { descriptor in
        ResourceBlob(id: descriptor.id, bytes: try #require(snapshot.bytes(for: descriptor.id)))
    }
    #expect(try PublicationSnapshot(manifest: restored, blobs: blobs).sourceBytes == snapshot.sourceBytes)
}
