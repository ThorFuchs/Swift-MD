import Foundation
import Testing
@testable import SwiftMDExport

@Test func rangesNormalizeAndRejectInvalidInput() throws {
    #expect(try ExportPageSelection.ranges("8, 1-3, 2, 5").resolve(pageCount: 8) == [1,2,3,5,8])
    #expect(try ExportPageSelection.single(7).resolve(pageCount: 7) == [7])
    for input in ["", "1,", "2-1", "1--2", "+1", "1, ,2", "9999999999999999999999999"] {
        #expect(throws: ExportPageSelection.Failure.invalidSyntax) { try ExportPageSelection.ranges(input).resolve(pageCount: 8) }
    }
    #expect(throws: ExportPageSelection.Failure.outOfBounds) { try ExportPageSelection.ranges("1-9").resolve(pageCount: 8) }
    #expect(throws: ExportPageSelection.Failure.tooManyPages) { try ExportPageSelection.ranges("1-5").resolve(pageCount: 8, maximumPages: 4) }
}

@Test func dimensionsUseRotationAndDPI() throws {
    let a = try ExportBitmapDimensions(widthPoints: 200, heightPoints: 300, rotation: 90, dpi: 144)
    #expect(a.width == 600 && a.height == 400 && a.rgbaBytes == 960_000)
    let b = try ExportBitmapDimensions(widthPoints: 72, heightPoints: 36, rotation: 0, dpi: 600)
    #expect(b.width == 600 && b.height == 300)
    #expect(throws: ExportPageSelection.Failure.outOfBounds) {
        try ExportBitmapDimensions(widthPoints: .infinity, heightPoints: 1, rotation: 0, dpi: 72)
    }
}

@Test func packagingIsBoundedAndDeterministicWhereSpecified() throws {
    let parts = [("main.typ", Data("Grüße".utf8)), ("theme.typ", Data("theme".utf8))]
    let zip = try ExportPackageZIP.encode(parts)
    #expect(zip == (try ExportPackageZIP.encode(parts)))
    #expect(throws: ExportPackageZIP.Failure.invalidEntry) { try ExportPackageZIP.encode([("a",Data()),("A",Data())]) }
    #expect(throws: ExportPackageZIP.Failure.invalidEntry) { try ExportPackageZIP.encode([("../a",Data())]) }
    let html = Data("<html>Grüße</html>".utf8)
    let raster = WebPageExport.Raster(index: 1, isPNG: true, bytes: Data([1,2,3]))
    #expect(throws: WebPageExportError.invalidHTML) {
        try WebPageExport(standaloneHTML: html, archiveHTML: html, rasters: [raster,raster], unresolvedMediaCount: 0, hasInertLinks: false)
    }
    let page = try WebPageExport(externalHTML: html)
    #expect(try page.encode(.html) == html)
    let archive = try #require(PropertyListSerialization.propertyList(from: page.encode(.webArchive), format: nil) as? [String:Any])
    let main = try #require(archive["WebMainResource"] as? [String:Any])
    #expect(main["WebResourceData"] as? Data == html)
}
