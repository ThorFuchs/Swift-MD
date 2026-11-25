import Foundation
import Testing
@testable import SwiftMDExport

@Test func storedInventoryChecksBothHeadersPayloadAndCRC() throws {
    let parts = [("main.typ", Data("Grüße 🦊".utf8)), ("theme.typ", Data("theme".utf8)), ("empty", Data())]
    let archive = try ExportPackageZIP.encode(parts)
    let inventory = try GeneratedArchiveInventory.inspect(archive, kind: .storedZIP)
    #expect(inventory.entries.map(\.name) == parts.map(\.0))
    #expect(inventory.entries.map(\.byteCount) == parts.map { $0.1.count })
    #expect(inventory.validation.contains("CRC-32"))
    var changed = archive
    changed[30 + parts[0].0.utf8.count] ^= 0xff
    #expect(throws: GeneratedArchiveInventory.Failure.invalid) {
        try GeneratedArchiveInventory.inspect(changed, kind: .storedZIP)
    }
    changed = archive
    let directory = try #require(changed.range(of: Data([0x50,0x4b,0x01,0x02])))
    changed[directory.lowerBound + 42] = 1
    #expect(throws: GeneratedArchiveInventory.Failure.invalid) {
        try GeneratedArchiveInventory.inspect(changed, kind: .storedZIP)
    }
    for length in [0, 1, 21, archive.count - 1] {
        #expect(throws: (any Error).self) {
            try GeneratedArchiveInventory.inspect(Data(archive.prefix(length)), kind: .storedZIP)
        }
    }
}

@Test func webArchiveInventoriesReadActualContainers() throws {
    let raster = WebPageExport.Raster(index: 1, isPNG: true, bytes: Data([1,2,3,4,5]))
    let html = Data("<html>Grüße 🦊</html>".utf8)
    let page = try WebPageExport(standaloneHTML: html, archiveHTML: html, rasters: [raster],
                                 unresolvedMediaCount: 0, hasInertLinks: false)
    for (encoding, kind): (WebPageExportEncoding, GeneratedArchiveKind) in [(.webArchive,.webArchive),(.mhtml,.mhtml),(.warc,.warc)] {
        let bytes = try page.encode(encoding)
        let inventory = try GeneratedArchiveInventory.inspect(bytes, kind: kind)
        #expect(inventory.entries.suffix(2).map(\.name) == ["index.html", "assets/1.png"])
        #expect(inventory.entries.suffix(2).map(\.byteCount) == [html.count, raster.bytes.count])
        #expect(inventory.entries.last?.mediaType == "image/png")
        #expect(throws: (any Error).self) {
            try GeneratedArchiveInventory.inspect(Data(bytes.dropLast()), kind: kind)
        }
    }
}

@Test func lineEndingVariantsPreserveUnicodeAndDoNotDoubleCRLF() {
    let input = "Grüße 🦊\r\nsecond\rthird\n"
    #expect(ExportTextOutput.encode(input, lineEndings: .lf) == Data("Grüße 🦊\nsecond\nthird\n".utf8))
    #expect(ExportTextOutput.encode(input, lineEndings: .crlf) == Data("Grüße 🦊\r\nsecond\r\nthird\r\n".utf8))
}

@Test func latexWrapperRetainsTheBackendFragmentAndPaperChoice() {
    let fragment = "\\section{Grüße}\nA \\textbf{strong} statement."
    let a4 = ExportTextOutput.latexArticle(fragment)
    #expect(a4.contains("\\documentclass[11pt,a4paper]{article}"))
    #expect(a4.contains("\\begin{document}\n\n" + fragment + "\n\n\\end{document}"))
    #expect(ExportTextOutput.latexArticle(fragment, letter: true).contains("letterpaper"))
}
