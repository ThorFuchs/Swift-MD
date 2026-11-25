// SPDX-License-Identifier: Apache-2.0
#if os(macOS) && canImport(PDFKit)
import Foundation
import PDFKit

public enum PDFOutputOptimization: Sendable { case original, screen, compact }

public struct PDFOutputResult: Sendable {
    public let data: Data
    public let pageCount: Int
    public let rewritten: Bool
    public let subset: Bool
}

/// Native PDF post-processing of caller-owned bytes, never a live PDFView.
/// Whole-document original mode preserves the exact input bytes. Every
/// rewritten output checks page count, geometry, rotation and extracted text.
/// This is NOT validation of outlines, links, tags, PDF/A, PDF/X or visual equality.
@MainActor
public enum PDFOutputWriter {
    public enum Failure: LocalizedError, Equatable, Sendable {
        case invalidPDF, changedPDF, budget
        public var errorDescription: String? {
            switch self {
            case .invalidPDF: "The PDF could not be opened or rewritten."
            case .changedPDF: "The PDF rewrite changed page geometry or extracted text."
            case .budget: "The PDF rewrite exceeds the 200-page limit."
            }
        }
    }

    public static func make(_ data: Data, expectedPageCount: Int,
                            selection: ExportPageSelection = .all,
                            optimization: PDFOutputOptimization = .original) throws -> PDFOutputResult {
        try Task.checkCancellation()
        guard let original = PDFDocument(data: data), expectedPageCount > 0,
              original.pageCount == expectedPageCount else { throw Failure.invalidPDF }
        if selection == .all && optimization == .original {
            return PDFOutputResult(data: data, pageCount: original.pageCount, rewritten: false, subset: false)
        }
        let numbers = try selection.resolve(pageCount: original.pageCount, maximumPages: 200)
        let subset = numbers.count != original.pageCount
        if !subset && optimization == .original {
            return PDFOutputResult(data: data, pageCount: original.pageCount, rewritten: false, subset: false)
        }
        guard numbers.count <= 200 else { throw Failure.budget }
        struct Record {
            let media: CGRect, crop: CGRect
            let rotation: Int
            let text: String?
            init(_ page: PDFPage) {
                media = page.bounds(for: .mediaBox); crop = page.bounds(for: .cropBox)
                rotation = page.rotation; text = page.string
            }
            func matches(_ page: PDFPage) -> Bool {
                media == page.bounds(for: .mediaBox) && crop == page.bounds(for: .cropBox)
                    && rotation == page.rotation && text == page.string
            }
        }
        var records: [Record] = []
        let selected = subset ? PDFDocument() : original
        for number in numbers {
            try Task.checkCancellation()
            guard let page = original.page(at: number - 1) else { throw Failure.invalidPDF }
            records.append(Record(page))
            if subset {
                guard let copy = page.copy() as? PDFPage else { throw Failure.invalidPDF }
                selected.insert(copy, at: selected.pageCount)
            }
        }
        var options: [AnyHashable: Any] = [:]
        if optimization != .original { options[PDFDocumentWriteOption.optimizeImagesForScreenOption] = true }
        if optimization == .compact { options[PDFDocumentWriteOption.saveImagesAsJPEGOption] = true }
        guard let encoded = selected.dataRepresentation(options: options),
              let decoded = PDFDocument(data: encoded) else { throw Failure.invalidPDF }
        try Task.checkCancellation()
        guard decoded.pageCount == records.count else { throw Failure.changedPDF }
        for (index, record) in records.enumerated() {
            guard let page = decoded.page(at: index), record.matches(page) else { throw Failure.changedPDF }
        }
        return PDFOutputResult(data: encoded, pageCount: decoded.pageCount, rewritten: true, subset: subset)
    }
}
#endif
