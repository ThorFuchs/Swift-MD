// SPDX-License-Identifier: Apache-2.0

import Foundation
import SwiftGFM
import SwiftMD
import Testing

// Unmodified upstream sources and reproduction details are in Fixtures/cmark-gfm.
private enum UpstreamSuite: String, CaseIterable, Sendable {
    case spec, extensions
    case fullInfo = "extensions-full-info-string"
    case tableStyle = "extensions-table-prefer-style-attributes"
}

private struct UpstreamExample: Sendable, CustomTestStringConvertible {
    let suite: UpstreamSuite
    let number: Int
    let section: String
    let startLine: Int
    let flags: [String]
    let markdown: String
    let expected: String

    var testDescription: String { "\(suite.rawValue)#\(number) (line \(startLine)): \(section)" }
    var isDisabled: Bool { flags.contains("disabled") }
    var ignoresExpectedOutput: Bool { expected.trimmingCharacters(in: .whitespacesAndNewlines) == "<IGNORE>" }
}

private enum FixtureError: Error {
    case missing(String)
    case malformed(String)
    case unsupportedFlag(String)
}

private enum UpstreamFixtures {
    static let all: [UpstreamExample] = {
        // An unreadable or malformed bundled corpus is a test infrastructure
        // failure, not an empty list of passing examples.
        do { return try UpstreamSuite.allCases.flatMap(load) } catch {
            fatalError("Could not load cmark-gfm fixtures: \(error)")
        }
    }()

    static let compared = all.filter { !$0.isDisabled && !$0.ignoresExpectedOutput }
    static let roundTrips = compared.filter { [.spec, .extensions, .fullInfo, .tableStyle].contains($0.suite) }

    private static func load(_ suite: UpstreamSuite) throws -> [UpstreamExample] {
        guard
            let url = Bundle.module.url(
                forResource: suite.rawValue, withExtension: "txt", subdirectory: "Fixtures/cmark-gfm")
        else {
            throw FixtureError.missing(suite.rawValue)
        }
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8) else { throw FixtureError.malformed(suite.rawValue) }
        // Split UTF-8 on LF rather than relying on Swift's CRLF graphemes.
        let bytes = Array(text.utf8)
        let lines = bytes.split(separator: 10, omittingEmptySubsequences: false)
        let fence = String(repeating: "`", count: 32)
        var state = 0
        var section = ""
        var start = 0
        var flags: [String] = []
        var input = ""
        var expected = ""
        var examples: [UpstreamExample] = []
        for (offset, bytes) in lines.enumerated() {
            let line = String(decoding: bytes, as: UTF8.self)
            let content = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let terminated = offset < lines.count - 1
            if state == 0 && content.hasPrefix(fence + " example") {
                state = 1
                start = offset + 1
                flags = content.dropFirst((fence + " example").count).split(whereSeparator: \.isWhitespace).map(
                    String.init)
                input = ""
                expected = ""
            } else if state != 0 && content == fence {
                guard state == 2 else { throw FixtureError.malformed("\(suite.rawValue):\(start)") }
                examples.append(
                    UpstreamExample(
                        suite: suite, number: examples.count + 1, section: section,
                        startLine: start, flags: flags, markdown: input.replacingOccurrences(of: "→", with: "\t"),
                        expected: expected.replacingOccurrences(of: "→", with: "\t")))
                state = 0
            } else if state == 1 && content == "." {
                state = 2
            } else if state == 1 {
                input += line + (terminated ? "\n" : "")
            } else if state == 2 {
                expected += line + (terminated ? "\n" : "")
            } else if line.hasPrefix("#") {
                let heading = line.drop(while: { $0 == "#" })
                if heading.first == " " { section = heading.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        }
        guard state == 0 else { throw FixtureError.malformed("\(suite.rawValue): unterminated example") }
        return examples
    }
}

private func configuration(for example: UpstreamExample) throws -> MarkdownConfiguration {
    var extensions: MarkdownExtensions = (example.suite == .extensions || example.suite == .tableStyle) ? .gfm : []
    var options: MarkdownOptions = [.allowUnsafeHTML]
    if example.suite == .extensions || example.suite == .tableStyle { options.insert(.footnotes) }
    if example.suite == .fullInfo { options.insert(.fullInfoString) }
    if example.suite == .tableStyle { options.insert(.tableStyleAttributes) }
    for flag in example.flags {
        switch flag {
        case "table": extensions.insert(.table)
        case "strikethrough": extensions.insert(.strikethrough)
        case "autolink": extensions.insert(.autolink)
        case "tagfilter": extensions.insert(.tagFilter)
        case "tasklist": extensions.insert(.taskList)
        case "footnotes": options.insert(.footnotes)
        default: throw FixtureError.unsupportedFlag(flag)
        }
    }
    return MarkdownConfiguration(extensions: extensions, options: options)
}

@Test("Bundled cmark-gfm examples: exact HTML bytes", arguments: UpstreamFixtures.compared)
private func bundledCMarkExample(_ example: UpstreamExample) throws {
    let actual = try MarkdownCompiler(configuration: configuration(for: example)).render(example.markdown).html
    #expect(
        Array(actual.utf8) == Array(example.expected.utf8),
        "\(example.testDescription)\nInput: \(String(reflecting: example.markdown))\nExpected: \(String(reflecting: example.expected))\nActual: \(String(reflecting: actual))"
    )
}

@Test("Bundled cmark-gfm fixture inventory")
private func bundledCMarkInventory() {
    let bySuite = Dictionary(grouping: UpstreamFixtures.all, by: \.suite)
    #expect(bySuite[.spec]?.count == 672)
    #expect(bySuite[.extensions]?.count == 30)
    #expect(bySuite[.fullInfo]?.count == 4)
    #expect(bySuite[.tableStyle]?.count == 1)
    #expect(UpstreamFixtures.compared.count == 704)
    #expect(UpstreamFixtures.all.filter(\.isDisabled).map(\.number) == [279, 280])
    #expect(
        UpstreamFixtures.all.filter(\.ignoresExpectedOutput).map { "\($0.suite.rawValue)#\($0.number)" } == [
            "extensions#20"
        ])
}

@Test("cmark-gfm spec example 279", .disabled("Marked disabled in the pinned upstream fixture"))
private func upstreamDisabled279() {}
@Test("cmark-gfm spec example 280", .disabled("Marked disabled in the pinned upstream fixture"))
private func upstreamDisabled280() {}
@Test(
    "cmark-gfm extensions example 20",
    .disabled("Upstream expected output is <IGNORE>, so there is no expected HTML to compare"))
private func upstreamIgnoredExtension20() {}

// Optional independent upstream executable; build it from the documented pinned
// source commit. Include the <IGNORE> input because this is a backend comparison.
@Test(
    "Independent cmark-gfm executable comparison",
    .enabled(if: ProcessInfo.processInfo.environment["SWIFTMD_CMARK_REFERENCE"] != nil,
             "Set SWIFTMD_CMARK_REFERENCE to run the independent renderer comparison"))
private func independentReference() throws {
    guard let executable = ProcessInfo.processInfo.environment["SWIFTMD_CMARK_REFERENCE"] else {
        Issue.record("SWIFTMD_CMARK_REFERENCE disappeared after test selection")
        return
    }
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("swiftmd-reference-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: dir) }
    let input = dir.appendingPathComponent("input"), output = dir.appendingPathComponent("output")
    var count = 0
    for example in UpstreamFixtures.all where !example.isDisabled {
        let config = try configuration(for: example)
        var args = ["--unsafe"]
        if config.options.contains(.smartPunctuation) { args.append("--smart") }
        if config.options.contains(.fullInfoString) { args.append("--full-info-string") }
        if config.options.contains(.tableStyleAttributes) { args.append("--table-prefer-style-attributes") }
        if config.options.contains(.footnotes) { args += ["-e", "footnotes"] }
        let extensions: [(MarkdownExtensions, String)] = [(.table, "table"), (.autolink, "autolink"), (.strikethrough, "strikethrough"), (.tagFilter, "tagfilter"), (.taskList, "tasklist")]
        for (flag, name) in extensions where config.extensions.contains(flag) { args += ["-e", name] }
        try Data(example.markdown.utf8).write(to: input)
        try Data().write(to: output)
        let inputHandle = try FileHandle(forReadingFrom: input), outputHandle = try FileHandle(forWritingTo: output)
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args; process.standardInput = inputHandle; process.standardOutput = outputHandle
        try process.run(); process.waitUntilExit()
        try inputHandle.close(); try outputHandle.close()
        #expect(process.terminationStatus == 0, "Reference failed: \(example.testDescription)")
        let actual = try MarkdownCompiler(configuration: config).render(example.markdown).html
        let reference = try Data(contentsOf: output)
        #expect(Data(actual.utf8) == reference, "Reference mismatch: \(example.testDescription)")
        count += 1
    }
    #expect(count == 705)
    print("Independent cmark comparison: \(count) examples")
}
