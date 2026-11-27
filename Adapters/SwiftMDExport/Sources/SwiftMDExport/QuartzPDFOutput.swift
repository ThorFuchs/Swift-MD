// SPDX-License-Identifier: Apache-2.0
#if os(macOS) && canImport(Quartz)
import Foundation
import Quartz
import CoreGraphics
import PDFKit

/// System-installed filters only; no arbitrary paths, user filter contents,
/// shell command, or hidden conformance promise. Native verification required.
public struct QuartzPDFProfile: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
}

@MainActor
public enum QuartzPDFOutput {
    private static let root = URL(fileURLWithPath: "/System/Library/Filters", isDirectory: true)

    public enum Failure: LocalizedError, Equatable, Sendable {
        case unavailable, unsupportedGeometry, rejected, changed, budget
        public var errorDescription: String? {
            switch self {
            case .unavailable: "This installed Quartz filter is not available."
            case .unsupportedGeometry: "Quartz redraw currently requires unrotated pages with matching zero-origin media and crop boxes."
            case .rejected: "Quartz rejected the filter or could not create a PDF."
            case .changed: "The filtered PDF changed page geometry or extracted text."
            case .budget: "The Quartz transformation exceeds the export budget."
            }
        }
    }

    private static func installed() -> [(QuartzPDFProfile, QuartzFilter)] {
        let urls = (try? FileManager.default.contentsOfDirectory(at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles])) ?? []
        return urls.sorted { $0.lastPathComponent < $1.lastPathComponent }.prefix(128).compactMap { url in
            guard url.pathExtension.lowercased() == "qfilter",
                  let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey]),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let filter = QuartzFilter(url: url) else { return nil }
            let name = filter.localizedName() ?? url.deletingPathExtension().lastPathComponent
            return (QuartzPDFProfile(id: url.lastPathComponent, title: name), filter)
        }
    }

    public static func profiles() -> [QuartzPDFProfile] { installed().map(\.0) }

    /// Apply the public QuartzFilter context API and redraw actual PDF
    /// content. Preserve text/geometry or fail; annotations, links, outlines,
    /// tags, ICC and PDF/A/X semantics are NOT certified by this check.
    public static func apply(_ data: Data, profileID: String) throws -> Data {
        try Task.checkCancellation()
        guard let filter = installed().first(where: { $0.0.id == profileID })?.1 else {
            throw Failure.unavailable
        }
        guard let original = PDFDocument(data: data),
              let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider), original.pageCount > 0,
              original.pageCount == pdf.numberOfPages else { throw Failure.rejected }
        guard pdf.numberOfPages <= 200, data.count <= 64 * 1024 * 1024 else { throw Failure.budget }
        var boxes: [CGRect] = []
        for number in 1...pdf.numberOfPages {
            guard let page = pdf.page(at: number) else { throw Failure.rejected }
            let box = page.getBoxRect(.mediaBox)
            guard page.rotationAngle == 0, box.origin == .zero, box.width.isFinite, box.height.isFinite,
                  box.width > 0, box.height > 0, box == page.getBoxRect(.cropBox) else {
                throw Failure.unsupportedGeometry
            }
            boxes.append(box)
        }
        let bytes = NSMutableData()
        guard let consumer = CGDataConsumer(data: bytes as CFMutableData) else { throw Failure.rejected }
        var first = boxes[0]
        guard let context = CGContext(consumer: consumer, mediaBox: &first, nil) else { throw Failure.rejected }
        guard filter.apply(to: context) else { context.closePDF(); throw Failure.rejected }
        do {
            for (index, box) in boxes.enumerated() {
                try Task.checkCancellation()
                guard let page = pdf.page(at: index + 1) else { throw Failure.rejected }
                var geometry = box
                let encoded = withUnsafeBytes(of: &geometry) { Data($0) }
                context.beginPDFPage([kCGPDFContextMediaBox as String: encoded] as CFDictionary)
                context.drawPDFPage(page)
                context.endPDFPage()
            }
        } catch {
            filter.remove(from: context)
            context.closePDF()
            throw error
        }
        context.closePDF()
        filter.remove(from: context)
        let output = bytes as Data
        guard output.count <= 64 * 1024 * 1024 else { throw Failure.budget }
        guard let decoded = PDFDocument(data: output), decoded.pageCount == original.pageCount else { throw Failure.changed }
        for i in 0..<original.pageCount {
            guard let a = original.page(at: i), let b = decoded.page(at: i),
                  a.bounds(for: .mediaBox) == b.bounds(for: .mediaBox),
                  a.bounds(for: .cropBox) == b.bounds(for: .cropBox),
                  a.rotation == b.rotation, a.string == b.string else { throw Failure.changed }
        }
        return output
    }
}
#endif
