// SPDX-License-Identifier: Apache-2.0
import Foundation

/// Deterministic, stored-only ZIP subset for generated ODT.
/// No filesystem reads, compression, encryption, ZIP64 or caller-supplied paths.
enum StoredZIP {
    enum Failure: LocalizedError {
        case invalidEntry, tooLarge
        var errorDescription: String? {
            switch self {
            case .invalidEntry: "Invalid generated archive entry."
            case .tooLarge: "The generated archive exceeds the 64 MiB limit."
            }
        }
    }

    static let maximumBytes = 64 * 1024 * 1024

    static func encode(_ entries: [(String, Data)]) throws -> Data {
        guard !entries.isEmpty, entries.count <= 512 else { throw Failure.invalidEntry }
        var seen = Set<String>()
        var size = 22
        for (name, bytes) in entries {
            let parts = name.split(separator: "/", omittingEmptySubsequences: false)
            guard !name.isEmpty, name.utf8.count <= 200,
                  parts.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
                  name.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0)
                      || (97...122).contains($0) || [45,46,47,95].contains($0) }),
                  seen.insert(name.lowercased()).inserted else { throw Failure.invalidEntry }
            let overhead = 76 + 2 * name.utf8.count
            guard bytes.count <= maximumBytes - size - overhead else { throw Failure.tooLarge }
            size += overhead + bytes.count
        }
        var output = Data(), central = Data()
        output.reserveCapacity(size)
        for (name, bytes) in entries {
            try Task.checkCancellation()
            let filename = Data(name.utf8)
            let length = UInt32(bytes.count), offset = UInt32(output.count), crc = checksum(bytes)
            let n = UInt16(filename.count)
            output.appendLE(UInt32(0x04034b50))
            output.appendLE(UInt16(20)); output.appendLE(UInt16(0x0800))
            output.appendLE(UInt16(0)); output.appendLE(UInt16(0)); output.appendLE(UInt16(0x0021))
            output.appendLE(crc); output.appendLE(length); output.appendLE(length)
            output.appendLE(n); output.appendLE(UInt16(0))
            output.append(filename); output.append(bytes)

            central.appendLE(UInt32(0x02014b50))
            central.appendLE(UInt16(20)); central.appendLE(UInt16(20)); central.appendLE(UInt16(0x0800))
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0x0021))
            central.appendLE(crc); central.appendLE(length); central.appendLE(length); central.appendLE(n)
            central.appendLE(UInt16(0)); central.appendLE(UInt16(0)); central.appendLE(UInt16(0))
            central.appendLE(UInt16(0)); central.appendLE(UInt32(0)); central.appendLE(offset)
            central.append(filename)
        }
        let offset = UInt32(output.count)
        output.append(central)
        output.appendLE(UInt32(0x06054b50))
        output.appendLE(UInt16(0)); output.appendLE(UInt16(0))
        output.appendLE(UInt16(entries.count)); output.appendLE(UInt16(entries.count))
        output.appendLE(UInt32(central.count)); output.appendLE(offset); output.appendLE(UInt16(0))
        guard output.count == size else { throw Failure.invalidEntry }
        return output
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 { value = (value >> 1) ^ ((value & 1) == 1 ? 0xedb88320 : 0) }
        return value
    }

    private static func checksum(_ bytes: Data) -> UInt32 {
        var value: UInt32 = 0xffffffff
        for byte in bytes {
            value = (value >> 8) ^ crcTable[Int((value ^ UInt32(byte)) & 255)]
        }
        return ~value
    }
}

private extension Data {
    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var encoded = value.littleEndian
        Swift.withUnsafeBytes(of: &encoded) { append(contentsOf: $0) }
    }
}
