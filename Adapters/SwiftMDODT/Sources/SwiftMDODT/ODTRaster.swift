// SPDX-License-Identifier: Apache-2.0
import Foundation

public enum ODTRasterFormat: String, Sendable {
    case png, jpeg

    var fileExtension: String { self == .png ? "png" : "jpg" }
    var mime: String { self == .png ? "image/png" : "image/jpeg" }
}

/// Explicit caller-owned, already codec-validated capture. The destination
/// is an exact parsed Markdown image key, never a filesystem or URL lookup.
/// Portable admission checks framing/format and dimensions, NOT a full decode.
/// Embedded bytes (including metadata) are preserved unchanged.
public struct ODTRaster: Sendable {
    public let destination: String
    public let format: ODTRasterFormat
    public let bytes: Data
    public let pixelWidth: Int
    public let pixelHeight: Int

    public init(destination: String, format: ODTRasterFormat, bytes: Data) throws {
        guard !destination.isEmpty, destination.utf8.count <= 4096,
              !bytes.isEmpty, bytes.count <= 16 * 1024 * 1024 else {
            throw ODTError.imageBudget
        }
        let dimensions = try Self.dimensions(Array(bytes), format: format)
        guard (1...8192).contains(dimensions.0), (1...8192).contains(dimensions.1),
              dimensions.0 * dimensions.1 <= 16_000_000 else { throw ODTError.imageBudget }
        self.destination = destination; self.format = format; self.bytes = bytes
        pixelWidth = dimensions.0; pixelHeight = dimensions.1
    }

    private static func dimensions(_ b: [UInt8], format: ODTRasterFormat) throws -> (Int, Int) {
        switch format {
        case .png:
            guard b.count >= 45, b.prefix(8).elementsEqual([137,80,78,71,13,10,26,10]),
                  b[8..<16].elementsEqual([0,0,0,13,73,72,68,82]),
                  b.suffix(12).elementsEqual([0,0,0,0,73,69,78,68,174,66,96,130]) else {
                throw ODTError.invalidImage
            }
            func uint32(_ start: Int) -> Int {
                b[start..<start+4].reduce(0) { ($0 << 8) | Int($1) }
            }
            return (uint32(16), uint32(20))
        case .jpeg:
            guard b.count >= 12, b.prefix(2).elementsEqual([255,216]),
                  b.suffix(2).elementsEqual([255,217]) else { throw ODTError.invalidImage }
            var i = 2
            // Supported frame headers: baseline, extended sequential and progressive.
            // Reject malformed segment lengths; do not scan the entropy-coded body.
            while i < b.count - 1 {
                guard b[i] == 255 else { throw ODTError.invalidImage }
                while i < b.count && b[i] == 255 { i += 1 }
                guard i < b.count else { throw ODTError.invalidImage }
                let marker = b[i]; i += 1
                guard marker != 0, marker != 0xda, marker != 0xd9,
                      marker != 0xd8, marker != 1, !(0xd0...0xd7).contains(marker),
                      i + 2 <= b.count else { throw ODTError.invalidImage }
                let length = Int(b[i]) * 256 + Int(b[i+1])
                guard length >= 2, length <= b.count - i else { throw ODTError.invalidImage }
                if [0xc0,0xc1,0xc2].contains(marker) {
                    guard length >= 8 else { throw ODTError.invalidImage }
                    let height = Int(b[i+3]) * 256 + Int(b[i+4])
                    let width = Int(b[i+5]) * 256 + Int(b[i+6])
                    let components = Int(b[i+7])
                    guard [1,3,4].contains(components), length == 8 + 3 * components else {
                        throw ODTError.invalidImage
                    }
                    return (width, height)
                }
                i += length
            }
            throw ODTError.invalidImage
        }
    }
}
