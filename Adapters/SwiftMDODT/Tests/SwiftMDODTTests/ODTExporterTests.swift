// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import SwiftMDODT

private func fixtures() throws -> (ODTRaster, ODTRaster) {
    let png = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAEAAAAAgCAIAAAAt/+nTAAAAQ0lEQVR4nO3PQQ3AIADAQEAIOpGD1IngcVnSU9DOfc/4s6UDXjWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oDWgNaA1oH1R+gF21ZMy3AAAAABJRU5ErkJggg=="))
    let jpeg = try #require(Data(base64Encoded: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAAgAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwCpRRRVHxAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAf//Z"))
    return (try ODTRaster(destination: "figure.png", format: .png, bytes: png),
            try ODTRaster(destination: "../photo.jpg", format: .jpeg, bytes: jpeg))
}

/// Inspect the stored local entries of our own generated package. This is
/// intentionally not a general purpose untrusted archive decoder.
private func entries(_ package: Data) throws -> [(String, Data)] {
    let b = Array(package)
    func u16(_ n: Int) -> Int { Int(b[n]) | Int(b[n+1]) << 8 }
    func u32(_ n: Int) -> Int { u16(n) | u16(n+2) << 16 }
    var result: [(String,Data)] = [], i = 0
    while i+30 <= b.count && u32(i) == 0x04034b50 {
        let count = u32(i+18), nameLength = u16(i+26), extra = u16(i+28)
        try #require(u16(i+8) == 0 && extra == 0)
        let start = i+30+nameLength
        try #require(start <= b.count && count <= b.count-start)
        let name = try #require(String(bytes: b[i+30..<start], encoding: .utf8))
        result.append((name, Data(b[start..<start+count])))
        i = start + count
    }
    try #require(!result.isEmpty)
    return result
}

@Test func actualASTEmbedsExactPNGsAndJPEGsWithRepeatedReferences() throws {
    let (png, jpeg) = try fixtures()
    #expect(png.pixelWidth == 64 && png.pixelHeight == 32)
    #expect(jpeg.pixelWidth == 64 && jpeg.pixelHeight == 32)
    let markdown = """
    # Grüße &amp; Titel

    ![A &amp; B](figure.png "PNG")

    ![Foto](../photo.jpg "JPEG")

    Repeat ![Again](figure.png)

    | Image | Value |
    | --- | ---: |
    | ![Cell](figure.png) | 42 |
    """
    let exporter = ODTExporter()
    let output = try exporter.render(markdown, title: "Images", captures: [png, jpeg])
    let repeatOutput = try exporter.render(markdown, title: "Images", captures: [jpeg, png])
    #expect(output == repeatOutput)
    let files = try entries(output)
    #expect(files.map(\.0) == ["mimetype","content.xml","styles.xml","meta.xml",
                               "META-INF/manifest.xml","Pictures/image-0001.png","Pictures/image-0002.jpg"])
    let map = Dictionary(uniqueKeysWithValues: files)
    #expect(map["mimetype"] == Data("application/vnd.oasis.opendocument.text".utf8))
    #expect(map["Pictures/image-0001.png"] == png.bytes)
    #expect(map["Pictures/image-0002.jpg"] == jpeg.bytes)
    let body = String(decoding: try #require(map["content.xml"]), as: UTF8.self)
    let manifest = String(decoding: try #require(map["META-INF/manifest.xml"]), as: UTF8.self)
    #expect(body.components(separatedBy: "<draw:frame ").count == 5)
    #expect(body.components(separatedBy: "xlink:href=\"Pictures/image-0001.png\"").count == 4)
    #expect(body.contains("<svg:desc>A &amp; B</svg:desc>"))
    #expect(body.contains("<svg:title>JPEG</svg:title>"))
    #expect(!body.contains("../photo.jpg"))
    #expect(manifest.contains("manifest:full-path=\"Pictures/image-0001.png\" manifest:media-type=\"image/png\""))
    #expect(manifest.contains("manifest:full-path=\"Pictures/image-0002.jpg\" manifest:media-type=\"image/jpeg\""))
}

@Test func captureIdentityAndUnsupportedContentFailClosed() throws {
    let (png, _) = try fixtures()
    let e = ODTExporter()
    #expect(throws: ODTError.missingImage("figure.png")) {
        try e.render("![Missing](figure.png)", title: "Missing")
    }
    #expect(throws: ODTError.duplicateImage) {
        try e.render("![A](figure.png)", title: "Duplicate", captures: [png,png])
    }
    #expect(throws: ODTError.unusedImage) {
        try e.render("# No image", title: "Unused", captures: [png])
    }
    #expect(throws: ODTError.missingImage("https://example.org/p.png")) {
        try e.render("![Remote](https://example.org/p.png)", title: "Remote", captures: [png])
    }
    #expect(throws: ODTError.invalidImage) {
        try ODTRaster(destination: "wrong", format: .jpeg, bytes: png.bytes)
    }
    #expect(throws: ODTError.invalidImage) {
        try ODTRaster(destination: "truncated", format: .png, bytes: png.bytes.dropLast())
    }
    var oversized = png.bytes
    oversized.replaceSubrange(16..<20, with: [0,0,32,1])
    #expect(throws: ODTError.imageBudget) {
        try ODTRaster(destination: "oversize", format: .png, bytes: oversized)
    }
}

@Test func textOnlyAndImageOptionsRemainDeterministic() throws {
    let e = ODTExporter()
    let source = "# Heading\n\n**bold**, *italic* and Grüße."
    let a4 = try e.render(source, title: "Text")
    #expect(a4 == (try e.render(source, title: "Text")))
    let letter = try e.render(source, title: "Text", options: ODTOptions(letter: true, bodyFontSize: 12))
    #expect(letter != a4)
    let map = Dictionary(uniqueKeysWithValues: try entries(letter))
    #expect(map.count == 5)
    #expect(String(decoding: try #require(map["styles.xml"]), as: UTF8.self).contains("fo:page-width=\"8.5in\""))
}
