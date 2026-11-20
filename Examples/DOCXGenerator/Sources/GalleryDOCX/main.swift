// SPDX-License-Identifier: Apache-2.0
import Foundation
import SwiftMDDOCX

guard CommandLine.arguments.count == 3 else {
    FileHandle.standardError.write(Data("Usage: GalleryDOCX INPUT.md OUTPUT.docx\n".utf8))
    exit(2)
}
let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let markdown = try String(contentsOf: input, encoding: .utf8)
let document = try DOCXExporter().render(markdown)
try document.write(to: output, options: .atomic)
