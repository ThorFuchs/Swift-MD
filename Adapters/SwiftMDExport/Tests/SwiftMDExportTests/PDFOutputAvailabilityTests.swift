#if os(macOS) && canImport(PDFKit)
import Foundation
import CoreGraphics
import PDFKit
import Testing
@testable import SwiftMDExport

@Test @MainActor func pdfOptimizationRespectsNativeAvailability() throws {
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

    let unchanged = try PDFOutputWriter.make(original, expectedPageCount: 1)
    #expect(unchanged.data == original)
    #expect(!unchanged.rewritten)
    for optimization in [PDFOutputOptimization.screen, .compact] {
        if #available(macOS 13.4, *) {
            let output = try PDFOutputWriter.make(original, expectedPageCount: 1,
                                                  optimization: optimization)
            #expect(output.rewritten)
            #expect(output.pageCount == 1)
            let decoded = try #require(PDFDocument(data: output.data))
            #expect(decoded.page(at: 0)?.bounds(for: .mediaBox) == box)
        } else {
            #expect(throws: PDFOutputWriter.Failure.optimizationUnavailable) {
                try PDFOutputWriter.make(original, expectedPageCount: 1,
                                         optimization: optimization)
            }
        }
    }
    // No compression-ratio or pixel-equality claim for a geometry fixture.
}
#endif
