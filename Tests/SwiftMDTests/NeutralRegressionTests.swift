// SPDX-License-Identifier: Apache-2.0
// Independently written behavior checks; not copied upstream fixture cases.
import Foundation
import SwiftGFM
import SwiftMD
import Testing

private struct NeutralCase: Sendable, CustomTestStringConvertible {
    let name: String
    let input: String
    let expected: String
    let smart: Bool
    var gfm = false
    var footnotes = false
    var testDescription: String { name }
}

private let neutralCases: [NeutralCase] = [
    .init(name: "normalize mixed line endings", input: "Entry one\r\nEntry two\rEntry three\n",
          expected: "<p>Entry one\nEntry two\nEntry three</p>\n", smart: false),
    .init(name: "replace null scalar", input: "alpha\0omega\n",
          expected: "<p>alpha�omega</p>\n", smart: false),
    .init(name: "smart quotes dash and ellipsis", input: "\"Solar probe\" -- it's ready...\n",
          expected: "<p>“Solar probe” – it’s ready…</p>\n", smart: true),
    .init(name: "smart punctuation preserves code", input: "`\"Sensor\" -- ...` and \"signal\"\n",
          expected: "<p><code>&quot;Sensor&quot; -- ...</code> and “signal”</p>\n", smart: true),
    .init(name: "nested structures and unicode", input: "- Node 😀\n  - child &amp; leaf\n\n> Final line\n",
          expected: "<ul>\n<li>Node 😀\n<ul>\n<li>child &amp; leaf</li>\n</ul>\n</li>\n</ul>\n<blockquote>\n<p>Final line</p>\n</blockquote>\n", smart: false),
    .init(name: "link destination and title escaping", input: "[module](https://example.org/a?x=1&y=2 \"Sensor &amp; lens\")\n",
          expected: "<p><a href=\"https://example.org/a?x=1&amp;y=2\" title=\"Sensor &amp; lens\">module</a></p>\n", smart: false),
    .init(name: "escaped delimiters remain literal", input: "\\*not emphasis\\* and \\`not code\\`\n",
          expected: "<p>*not emphasis* and `not code`</p>\n", smart: false),
    .init(name: "table with inline formatting", input: "| Planet | State |\n| ------ | ----- |\n| Vega | ~~planned~~ **ready** |\n",
          expected: "<table>\n<thead>\n<tr>\n<th>Planet</th>\n<th>State</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>Vega</td>\n<td><del>planned</del> <strong>ready</strong></td>\n</tr>\n</tbody>\n</table>\n", smart: false, gfm: true),
    .init(name: "extended link with punctuation", input: "Visit https://example.org/probe?item=42&view=all.\n",
          expected: "<p>Visit <a href=\"https://example.org/probe?item=42&amp;view=all\">https://example.org/probe?item=42&amp;view=all</a>.</p>\n", smart: false, gfm: true),
    .init(name: "footnote with inline formatting", input: "Orbit note[^orbit].\n\n[^orbit]: Full **context**.\n",
          expected: "<p>Orbit note<sup class=\"footnote-ref\"><a href=\"#fn-orbit\" id=\"fnref-orbit\" data-footnote-ref>1</a></sup>.</p>\n<section class=\"footnotes\" data-footnotes>\n<ol>\n<li id=\"fn-orbit\">\n<p>Full <strong>context</strong>. <a href=\"#fnref-orbit\" class=\"footnote-backref\" data-footnote-backref data-footnote-backref-idx=\"1\" aria-label=\"Back to reference 1\">↩</a></p>\n</li>\n</ol>\n</section>\n", smart: false, gfm: true, footnotes: true),
    .init(name: "task item with autolink and strikethrough", input: "- [x] See ~~old~~ https://example.org/new\n",
          expected: "<ul>\n<li><input type=\"checkbox\" checked=\"\" disabled=\"\" /> See <del>old</del> <a href=\"https://example.org/new\">https://example.org/new</a></li>\n</ul>\n", smart: false, gfm: true),
    .init(name: "nested smart quotation", input: "A pilot said, \"The caption reads 'launch'.\"\n",
          expected: "<p>A pilot said, “The caption reads ‘launch’.”</p>\n", smart: true),
    .init(name: "smart text inside link", input: "[\"Night sky\"](https://example.org/sky) -- ready...\n",
          expected: "<p><a href=\"https://example.org/sky\">“Night sky”</a> – ready…</p>\n", smart: true),
]

@Test("Independently written regression examples", arguments: neutralCases)
private func neutralRegression(_ example: NeutralCase) throws {
    var options: MarkdownOptions = [.allowUnsafeHTML]
    if example.smart { options.insert(.smartPunctuation) }
    if example.footnotes { options.insert(.footnotes) }
    let compiler = MarkdownCompiler(configuration: MarkdownConfiguration(extensions: example.gfm ? .gfm : [], options: options))
    #expect(try compiler.render(example.input).html == example.expected)
}

@Test(
    "Independent C comparison for neutral examples",
    .enabled(if: ProcessInfo.processInfo.environment["SWIFTMD_CMARK_REFERENCE"] != nil,
             "Set SWIFTMD_CMARK_REFERENCE to run the independent renderer comparison"),
    arguments: neutralCases)
private func neutralCComparison(_ example: NeutralCase) throws {
    guard let executable = ProcessInfo.processInfo.environment["SWIFTMD_CMARK_REFERENCE"] else {
        Issue.record("SWIFTMD_CMARK_REFERENCE disappeared after test selection")
        return
    }
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    let gfm = ["table", "strikethrough", "autolink", "tagfilter", "tasklist"].flatMap { ["-e", $0] }
    process.arguments = ["--unsafe"] + (example.smart ? ["--smart"] : []) +
        (example.footnotes ? ["-e", "footnotes"] : []) + (example.gfm ? gfm : [])
    let input = Pipe(), output = Pipe(), errors = Pipe()
    process.standardInput = input; process.standardOutput = output; process.standardError = errors
    try process.run()
    try input.fileHandleForWriting.write(contentsOf: Data(example.input.utf8))
    try input.fileHandleForWriting.close()
    let bytes = try output.fileHandleForReading.readToEnd() ?? Data()
    let errorBytes = try errors.fileHandleForReading.readToEnd() ?? Data()
    process.waitUntilExit()
    #expect(process.terminationStatus == 0, "Reference failed: \(String(decoding: errorBytes, as: UTF8.self))")
    #expect(bytes == Data(example.expected.utf8))
}
