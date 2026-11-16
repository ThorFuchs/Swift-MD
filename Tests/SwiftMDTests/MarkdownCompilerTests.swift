// SPDX-License-Identifier: Apache-2.0
import XCTest
import SwiftGFM
@testable import SwiftMD

final class MarkdownCompilerTests: XCTestCase {
    func testBaselineMatchesBackendAcrossConfigurationsAndInputs() throws {
        let configurations: [MarkdownConfiguration] = [
            .gfm, .cmarkDefault,
            .init(options: [.allowUnsafeHTML, .sourcePositions, .fullInfoString]),
            .init(options: [.githubPreLanguage]),
            .init(extensions: [.table, .autolink], options: [.allowUnsafeHTML])
        ]
        let inputs = ["", "# Hello\n\n[link](https://example.com)",
                      "| a | b |\n| - | - |\n| 1 | 2 |\n",
                      "```swift extra\nlet x = \"<hi>\"\n```\n",
                      "> ~~~math\r\n> x & y\r\n> ~~~\r\n",
                      "<pre><code class=\"language-swift\">raw</code></pre>\n",
                      "- one\n- [x] two\n\n$$\nx * y\n$$\n", "日本語 😀 & <"]
        for config in configurations {
            for input in inputs {
                let actual = try MarkdownCompiler(configuration: config).render(input)
                XCTAssertEqual(actual.html, try MarkdownEngine(configuration: config).render(input), "input: \(input), configuration: \(config)")
                XCTAssertTrue(actual.diagnostics.isEmpty)
            }
        }
    }

    func testKnownHTMLAndErrorPropagation() throws {
        XCTAssertEqual(try MarkdownCompiler().render("# Hello\n").html, "<h1>Hello</h1>\n")
        XCTAssertThrowsError(try MarkdownCompiler(configuration: .init(width: -1)).render("x"))
    }
}
