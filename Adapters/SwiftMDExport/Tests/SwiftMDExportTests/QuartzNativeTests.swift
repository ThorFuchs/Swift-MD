#if os(macOS) && canImport(Quartz)
import Foundation
import CoreGraphics
import PDFKit
import Testing
@testable import SwiftMDExport

@Test @MainActor func quartzRejectsUnknownFilterWithoutWritingAnything() throws {
    #expect(throws: QuartzPDFOutput.Failure.unavailable) {
        try QuartzPDFOutput.apply(Data(), profileID: "../untrusted.qfilter")
    }
}

@Test @MainActor func installedQuartzFilterCandidatePreservesSimplePageGeometry() throws {
    // Real SDK filter execution, only if this actual OS has a system size
    // filter. The explicit guard reports an unavailable filter, not a pass.
    let profile = try #require(QuartzPDFOutput.profiles().first {
        $0.id == "Reduce File Size.qfilter"
    }, "Install/identify the actual system Reduce File Size filter for this acceptance gate.")
    let storage = NSMutableData()
    let consumer = try #require(CGDataConsumer(data: storage as CFMutableData))
    var box = CGRect(x: 0, y: 0, width: 200, height: 300)
    let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
    context.beginPDFPage(nil)
    context.setFillColor(red: 0.8, green: 0.1, blue: 0.3, alpha: 1)
    context.fill(CGRect(x: 20, y: 30, width: 90, height: 80))
    context.endPDFPage()
    context.closePDF()
    let original = storage as Data
    let result = try QuartzPDFOutput.apply(original, profileID: profile.id)
    let document = try #require(PDFDocument(data: result))
    #expect(document.pageCount == 1)
    #expect(document.page(at: 0)?.bounds(for: .mediaBox) == box)
    // Geometry smoke test only; color/profile effect and external validation
    // still require independent inspection of real publication fixtures.
}
#endif
