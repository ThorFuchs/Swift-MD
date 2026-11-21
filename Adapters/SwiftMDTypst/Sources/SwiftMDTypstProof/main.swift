// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftMDTypst

private struct Heading: Encodable {
    let key: String
    let level: Int
    let title: String
}

@main
struct SwiftMDTypstProof {
    static func main() throws {
        guard CommandLine.arguments.count == 4 else {
            FileHandle.standardError.write(Data(
                "usage: SwiftMDTypstProof <input.md> <output.typ> <headings.json>\n".utf8
            ))
            exit(64)
        }
        let source = try String(
            contentsOfFile: CommandLine.arguments[1], encoding: .utf8
        )
        let projection = try TypstASTExporter().render(source)
        let document = """
        #set page(paper: "a4", margin: 20mm)
        #set text(font: "Libertinus Serif", size: 11pt)
        \(projection.body)

        """
        try document.write(
            toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let result = projection.headings.map {
            Heading(key: $0.key, level: $0.level, title: $0.title)
        }
        try encoder.encode(result).write(
            to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic
        )
        print("SWIFTMD TYPST: \(result.count) headings, \(document.utf8.count) Typst UTF8 bytes")
    }
}
