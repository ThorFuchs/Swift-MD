// SPDX-License-Identifier: Apache-2.0
import Testing
@testable import SwiftMDTypst

@Test func documentHeadingsHaveOrderedCrossRendererKeys() throws {
    let source = """
    # Report

    Text with **strong**, *emphasis*, ~~strike~~ and [source](https://example.org/one?q=1).

    ## First

    ## First

    ### Third
    """
    let document = try TypstASTExporter().render(source)
    #expect(document.headings.map(\.key) == ["vm-0", "vm-1", "vm-2", "vm-3"])
    #expect(document.headings.map(\.title) == ["Report", "First", "First", "Third"])
    #expect(document.headings.map(\.level) == [1, 2, 2, 3])
    #expect(document.headings[0].sourceRange?.start.line == 1)
    #expect(document.body.contains("#heading(level: 1)"))
    #expect(document.body.contains("<vm-0>"))
    #expect(document.body.contains("<vm-3>"))
    #expect(document.body.contains("#strong["))
    #expect(document.body.contains("#emph["))
    #expect(document.body.contains("#strike["))
    #expect(document.body.contains("#link(\"https://example.org/one?q=1\")"))
}

@Test func orderedListAndTablePreserveSourceStructure() throws {
    let source = """
    3) First
    4) Second

    - Alpha
    - Beta

    | Name | Value | Flag |
    | :--- | ---: | :---: |
    | A | 42 | OK |
    | B | 3 | no |
    """
    let output = try TypstASTExporter().render(source).body
    #expect(output.contains("#enum(start: 3, numbering: \"1)\", tight: true"))
    #expect(output.contains("#list(tight: true"))
    #expect(output.contains("#table(columns: 3, align: (left, right, center)"))
    #expect(output.contains("table.header("))
    #expect(output.contains("#text(\"42\")"))
}

@Test func sourceIsEncodedAsLiteralDataNotTypstCode() throws {
    let source = """
    # Escape

    A quote " and a backslash \\ and #let forbidden = true.

    ~~~swift
    let string = "#set page(fill: red)"
    ~~~
    """
    let out = try TypstASTExporter().render(source).body
    #expect(out.contains("\\\""))
    #expect(out.contains("#raw("))
    #expect(out.contains("#set page(fill: red)") == true)
    #expect(out.contains("lang: \"swift\""))
    #expect(!out.contains("\n#set page(fill: red)"))
}

@Test func mathFenceRequiresExplicitTrustedConverter() throws {
    let source = """
    ~~~math
    \\frac{1}{2}
    ~~~
    """
    #expect(throws: TypstProjectionError.unsupported("math fence requires trusted converter")) {
        _ = try TypstASTExporter().render(source)
    }
    let renderer = TypstASTExporter(trustedMathRenderer: { source in
        #expect(source.contains("\\frac"))
        return "$ frac(1, 2) $"
    })
    let result = try renderer.render(source)
    #expect(result.body.contains("$ frac(1, 2) $"))
}

@Test func rawHTMLImagesTasksAndFootnotesFailClosed() throws {
    let unsafe = [
        "<script>alert('x')</script>\n",
        "![image](file:///etc/passwd)\n",
        "- [x] done\n",
        "~~~mermaid\ngraph TD; A-->B\n~~~\n"
    ]
    for input in unsafe {
        #expect(throws: TypstProjectionError.self) {
            _ = try TypstASTExporter().render(input)
        }
    }
}

@Test func codeFencesPreserveLiteralAndUnknownLanguage() throws {
    let source = """
    ~~~unknown-super-language
    \"Hello\" and #let attack = true
    ~~~
    """
    let result = try TypstASTExporter().render(source)
    #expect(result.body.contains("block: true"))
    #expect(!result.body.contains("lang: \"unknown-super-language\""))
}

@Test func outputBudgetAndSourceSizeBounded() throws {
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstASTExporter(maximumOutputUTF8Bytes: 16).render("# Hello\n")
    }
    #expect(throws: TypstProjectionError.resourceBudget("source exceeds 1 MB")) {
        _ = try TypstASTExporter().render(String(repeating: "a", count: 1_000_001))
    }
}

@Test func unsafeInlineLinkRefusesCodeAndFileURLs() throws {
    for url in ["file:///etc/passwd", "javascript:alert(1)", "#local-heading"] {
        #expect(throws: TypstProjectionError.self) {
            _ = try TypstASTExporter().render("[bad](\(url))")
        }
    }
}

@Test func validNestedQuoteAndListDoNotDisappear() throws {
    let source = """
    > A **quote**.

    - Parent
      - Child

    ---
    """
    let result = try TypstASTExporter().render(source).body
    #expect(result.contains("#quote(block: true, quotes: false)"))
    #expect(result.contains("#list("))
    #expect(result.contains("#text(\"Child\")"))
    #expect(result.contains("#line(length: 100%)"))
}
