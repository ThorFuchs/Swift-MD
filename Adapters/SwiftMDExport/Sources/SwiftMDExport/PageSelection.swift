// SPDX-License-Identifier: Apache-2.0
import Foundation

/// One-based page selection; range strings normalize to ascending unique pages.
/// Bound expansion before allocating. Never silently clamp invalid requests.
public enum ExportPageSelection: Equatable, Sendable {
    case all, single(Int), ranges(String)
    public enum Failure: LocalizedError, Equatable, Sendable {
        case invalidSyntax, outOfBounds, tooManyPages
        public var errorDescription: String? {
            switch self {
            case .invalidSyntax: "Enter pages like 1-3, 5, 8."
            case .outOfBounds: "A selected page is not in the publication."
            case .tooManyPages: "The selection exceeds the export page limit."
            }
        }
    }

    public func resolve(pageCount: Int, maximumPages: Int = 2000) throws -> [Int] {
        guard pageCount > 0, maximumPages > 0, maximumPages <= 2000 else { throw Failure.outOfBounds }
        switch self {
        case .all:
            guard pageCount <= maximumPages else { throw Failure.tooManyPages }
            return Array(1...pageCount)
        case .single(let page):
            guard (1...pageCount).contains(page) else { throw Failure.outOfBounds }
            return [page]
        case .ranges(let raw):
            guard !raw.isEmpty, raw.utf8.count <= 512 else { throw Failure.invalidSyntax }
            var selected = Set<Int>()
            for entry in raw.split(separator: ",", omittingEmptySubsequences: false) {
                try Task.checkCancellation()
                let pieces = entry.split(separator: "-", omittingEmptySubsequences: false)
                guard (1...2).contains(pieces.count) else { throw Failure.invalidSyntax }
                func number(_ token: Substring) throws -> Int {
                    let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty, value.utf8.allSatisfy({ (48...57).contains($0) }),
                          let n = Int(value) else { throw Failure.invalidSyntax }
                    guard (1...pageCount).contains(n) else { throw Failure.outOfBounds }
                    return n
                }
                let lower = try number(pieces[0])
                let upper = try pieces.count == 2 ? number(pieces[1]) : lower
                guard upper >= lower else { throw Failure.invalidSyntax }
                guard upper - lower < maximumPages else { throw Failure.tooManyPages }
                for page in lower...upper {
                    selected.insert(page)
                    guard selected.count <= maximumPages else { throw Failure.tooManyPages }
                }
            }
            return selected.sorted()
        }
    }
}

/// Actual crop-box geometry; not an estimate of compressed output bytes.
public struct ExportBitmapDimensions: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public var pixels: Int { width * height }
    public var rgbaBytes: Int { pixels * 4 }

    public init(widthPoints: Double, heightPoints: Double, rotation: Int, dpi: Int) throws {
        guard [72,144,300,600].contains(dpi), [0,90,180,270].contains(rotation) else {
            throw ExportPageSelection.Failure.invalidSyntax
        }
        let swapped = rotation == 90 || rotation == 270
        let scale = Double(dpi) / 72
        let w = ceil((swapped ? heightPoints : widthPoints) * scale)
        let h = ceil((swapped ? widthPoints : heightPoints) * scale)
        guard w.isFinite, h.isFinite, (1...16384).contains(w), (1...16384).contains(h) else {
            throw ExportPageSelection.Failure.outOfBounds
        }
        width = Int(w); height = Int(h)
    }
}
