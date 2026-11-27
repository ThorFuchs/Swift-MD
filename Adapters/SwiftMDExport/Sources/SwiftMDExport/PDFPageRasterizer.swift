// SPDX-License-Identifier: Apache-2.0
#if canImport(CoreGraphics) && canImport(ImageIO) && canImport(UniformTypeIdentifiers)
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

public enum PDFRasterEncoding: String, Sendable { case png, jpg }

public struct PDFRasterOptions: Sendable {
    public let selection: ExportPageSelection
    public let dpi: Int
    public let encoding: PDFRasterEncoding
    public let jpegQuality: Int

    public init(selection: ExportPageSelection = .all, dpi: Int = 144,
                encoding: PDFRasterEncoding = .png, jpegQuality: Int = 90) {
        self.selection = selection; self.dpi = dpi; self.encoding = encoding; self.jpegQuality = jpegQuality
    }
}

public struct PDFRasterPlan: Equatable, Sendable {
    public struct Page: Equatable, Sendable {
        public let number: Int
        public let dimensions: ExportBitmapDimensions
    }
    public let sourcePageCount: Int
    public let pages: [Page]
    public let totalPixels: Int
    public let maximumPagePixels: Int
    public var maximumBufferBytes: Int { maximumPagePixels * 4 }
}

public struct PDFRasterPage: Identifiable, Sendable {
    public let number: Int
    public let width: Int
    public let height: Int
    public let data: Data
    public var id: Int { number }
}

/// Caller-owned PDF bytes; native rasterization, not a UI screenshot.
/// The plan is calculated from actual crop boxes before any raster allocation.
/// The encoded bytes may be larger or smaller than raw pixel-buffer estimates.
public enum PDFPageRasterizer {
    public static let maximumPages = 64
    public static let maximumPixelsPerPage = 16_000_000
    public static let maximumSingle600DPIPixels = 40_000_000
    public static let maximumTotalPixels = 120_000_000
    public static let maximumOutputBytes = 64 * 1024 * 1024

    public enum Failure: LocalizedError, Equatable, Sendable {
        case invalidPDF, invalidOptions, pixelBudget, outputBudget, encoding
        public var errorDescription: String? {
            switch self {
            case .invalidPDF: "The supplied PDF cannot be rendered."
            case .invalidOptions: "600 DPI is available for one selected page only; check the raster settings."
            case .pixelBudget: "The selected page geometry exceeds the pixel budget. Reduce resolution or select fewer pages."
            case .outputBudget: "The encoded images exceed the 64 MiB output limit."
            case .encoding: "Image encoding failed."
            }
        }
    }

    public static func plan(_ pdf: Data, options: PDFRasterOptions) throws -> PDFRasterPlan {
        try makePlan(open(pdf), options: options)
    }

    public static func render(_ pdf: Data, options: PDFRasterOptions) throws -> [PDFRasterPage] {
        let document = try open(pdf)
        let plan = try makePlan(document, options: options)
        var totalBytes = 0
        var pages: [PDFRasterPage] = []
        for entry in plan.pages {
            try Task.checkCancellation()
            guard let page = document.page(at: entry.number) else { throw Failure.invalidPDF }
            let bytes = try autoreleasepool {
                try encode(page, width: entry.dimensions.width, height: entry.dimensions.height, options: options)
            }
            guard bytes.count <= maximumOutputBytes - totalBytes else { throw Failure.outputBudget }
            totalBytes += bytes.count
            pages.append(PDFRasterPage(number: entry.number, width: entry.dimensions.width,
                                       height: entry.dimensions.height, data: bytes))
        }
        return pages
    }

    private static func open(_ pdf: Data) throws -> CGPDFDocument {
        guard let provider = CGDataProvider(data: pdf as CFData),
              let document = CGPDFDocument(provider), document.numberOfPages > 0 else {
            throw Failure.invalidPDF
        }
        return document
    }

    private static func makePlan(_ document: CGPDFDocument, options: PDFRasterOptions) throws -> PDFRasterPlan {
        guard [72,144,300,600].contains(options.dpi),
              [70,85,90,100].contains(options.jpegQuality) else { throw Failure.invalidOptions }
        let numbers = try options.selection.resolve(pageCount: document.numberOfPages, maximumPages: maximumPages)
        guard options.dpi != 600 || numbers.count == 1 else { throw Failure.invalidOptions }
        let pageLimit = options.dpi == 600 ? maximumSingle600DPIPixels : maximumPixelsPerPage
        var total = 0
        var pages: [PDFRasterPlan.Page] = []
        for number in numbers {
            try Task.checkCancellation()
            guard let page = document.page(at: number) else { throw Failure.invalidPDF }
            let box = page.getBoxRect(.cropBox)
            let rotation = ((Int(page.rotationAngle) % 360) + 360) % 360
            let geometry = try ExportBitmapDimensions(widthPoints: Double(box.width), heightPoints: Double(box.height),
                                                      rotation: rotation, dpi: options.dpi)
            guard geometry.pixels <= pageLimit, geometry.pixels <= maximumTotalPixels - total else {
                throw Failure.pixelBudget
            }
            total += geometry.pixels
            pages.append(.init(number: number, dimensions: geometry))
        }
        return PDFRasterPlan(sourcePageCount: document.numberOfPages, pages: pages,
                             totalPixels: total, maximumPagePixels: pages.map(\.dimensions.pixels).max() ?? 0)
    }

    private static func encode(_ page: CGPDFPage, width: Int, height: Int,
                               options: PDFRasterOptions) throws -> Data {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw Failure.encoding }
        let rect = CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height))
        context.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
        context.fill(rect)
        context.concatenate(page.getDrawingTransform(.cropBox, rect: rect, rotate: 0, preserveAspectRatio: true))
        context.drawPDFPage(page)
        guard let image = context.makeImage() else { throw Failure.encoding }
        let buffer = NSMutableData()
        let type: UTType = options.encoding == .png ? .png : .jpeg
        guard let destination = CGImageDestinationCreateWithData(buffer as CFMutableData, type.identifier as CFString, 1, nil) else {
            throw Failure.encoding
        }
        var properties: [String: Any] = [
            kCGImagePropertyDPIWidth as String: options.dpi,
            kCGImagePropertyDPIHeight as String: options.dpi
        ]
        if options.encoding == .jpg {
            properties[kCGImageDestinationLossyCompressionQuality as String] = Double(options.jpegQuality) / 100
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination), buffer.length > 0 else { throw Failure.encoding }
        return buffer as Data
    }
}
#endif
