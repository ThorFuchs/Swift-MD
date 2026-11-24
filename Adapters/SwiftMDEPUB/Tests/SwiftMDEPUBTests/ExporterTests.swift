// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import SwiftMDEPUB

@Test func exporterProfilesAndSnapshotAreExplicit() throws {
    let source = Data([0xef, 0xbb, 0xbf]) + Data("# Hello\r\n\r\n**SwiftMD**\r\n".utf8)
    let exporter = EPUBExporter()
    let snapshot = try exporter.compile(source, title: "Hello", language: "en")
    #expect(snapshot.sourceBytes == source)
    let reading = try exporter.render(snapshot)
    let inclusive = try exporter.render(snapshot, profile: .includingSource)
    #expect(reading == (try EPUBWriter.write(snapshot, sourcePolicy: .readingOnly)))
    #expect(inclusive == (try EPUBWriter.write(snapshot, sourcePolicy: .includeSource)))
    #expect(reading != inclusive)
    #expect(try exporter.render(snapshot) == reading)
    #expect(try exporter.render(source, title: "Hello", language: "en").prefix(4) == Data([0x50, 0x4b, 3, 4]))
}

@Test func exporterDoesNotSilentlyLoseMissingImages() throws {
    #expect(throws: PublicationError.unresolvedMedia) {
        _ = try EPUBExporter().render(Data("![missing](file.png)".utf8), title: "Missing", language: "en")
    }
}
