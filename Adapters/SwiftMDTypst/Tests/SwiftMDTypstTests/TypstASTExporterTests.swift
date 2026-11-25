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

@Test func rawHTMLImagesAndUnrenderedMermaidFailClosed() throws {
    let unsafe = [
        "<script>alert('x')</script>\n",
        "![image](file:///etc/passwd)\n",
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


@Test func readerPreviewKeepsSupportedFormattingAndHeadingIDsAroundUnsupportedNodes() throws {
    let source = """
    # Report

    **Important** [local reference](../notes.md) and [web](https://example.org).

    ![Architecture diagram](file:///private/diagram.png)

    - [x] Done
    - [ ] Next

    <script>#read("/private/file")</script>

    ~~~mermaid
    graph TD; A-->B
    ~~~

    ## Results

    *Preserved text.*
    """
    let result = try TypstASTExporter(unsupportedContentPolicy: .readerPreview).render(source)
    #expect(result.headings.map(\.key) == ["vm-0", "vm-1"])
    #expect(result.headings.map(\.title) == ["Report", "Results"])
    #expect(result.body.contains("#strong["))
    #expect(result.body.contains("#emph["))
    #expect(result.body.contains("#link(\"https://example.org\")"))
    #expect(result.body.contains("#text(\"local reference\")"))
    #expect(!result.body.contains("#link(\"../notes.md\")"))
    #expect(result.body.contains("[Image: Architecture diagram]"))
    #expect(!result.body.contains("file:///private/diagram.png"))
    #expect(result.body.contains("#text(\"[x] \")"))
    #expect(result.body.contains("#text(\"[ ] \")"))
    #expect(result.body.contains("#raw("))
    #expect(!result.body.contains("\n#read("))
    #expect(Set(result.degradations) == [.linkAsText, .imageAsPlaceholder, .htmlAsText, .mermaidAsCode])
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstASTExporter().render(source)
    }
}

@Test func readerPreviewHeadingLabelMatchesInertLinkAndImageText() throws {
    let source = "# [Local](#target) ![diagram](https://example.org/diagram.png)"
    let result = try TypstASTExporter(unsupportedContentPolicy: .readerPreview).render(source)
    #expect(result.headings.map(\.title) == ["Local [Image: diagram]"])
    #expect(result.body.contains("#text(\"Local\")"))
    #expect(result.body.contains("#text(\"[Image: diagram]\")"))
    #expect(!result.body.contains("#link("))
    #expect(result.degradations == [.linkAsText, .imageAsPlaceholder])
}

@Test func readerPreviewRetainsMathAsCodeOnlyWithoutTrustedConverter() throws {
    let source = "~~~math\n\\frac{1}{2}\n~~~"
    let result = try TypstASTExporter(unsupportedContentPolicy: .readerPreview).render(source)
    #expect(result.degradations == [.mathAsCode])
    #expect(result.body.contains("#raw("))
    #expect(throws: TypstProjectionError.resourceBudget("trusted math budget")) {
        _ = try TypstASTExporter(
            unsupportedContentPolicy: .readerPreview,
            trustedMathRenderer: { _ in throw TypstProjectionError.resourceBudget("trusted math budget") }
        ).render(source)
    }
}

@Test func readerPreviewDoesNotBypassOutputBudgetOrUnsafeStringGuard() throws {
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstASTExporter(
            maximumOutputUTF8Bytes: 16, unsupportedContentPolicy: .readerPreview
        ).render("![A long description](file:///private/file)")
    }
    #expect(throws: TypstProjectionError.resourceBudget("source exceeds 1 MB")) {
        _ = try TypstASTExporter(unsupportedContentPolicy: .readerPreview)
            .render(String(repeating: "x", count: 1_000_001))
    }
}


@Test func strictTaskListsKeepStateNestedBlocksInlineFormattingAndHeadings() throws {
    let source = """
    # Start

    Introductory **formatted** prose.

    - [x] Completed **task**
      - [ ] Nested *pending* task
    - Ordinary bullet
    - [ ] Open task

    3) [x] Ordered completed
    4) [ ] Ordered pending

    ## Finish

    Trailing ~~removed~~ text.
    """
    let strict = try TypstASTExporter().render(source)
    let preview = try TypstASTExporter(unsupportedContentPolicy: .readerPreview).render(source)
    #expect(strict.body == preview.body)
    #expect(strict.headings == preview.headings)
    #expect(strict.degradations.isEmpty && preview.degradations.isEmpty)
    #expect(strict.headings.map(\.title) == ["Start", "Finish"])
    #expect(strict.headings.map(\.key) == ["vm-0", "vm-1"])
    #expect(strict.body.components(separatedBy: "#text(\"[x] \")").count == 3)
    #expect(strict.body.components(separatedBy: "#text(\"[ ] \")").count == 4)
    #expect(strict.body.contains("#enum(start: 3, numbering: \"1)\""))
    #expect(strict.body.components(separatedBy: "#list(").count >= 3)
    #expect(strict.body.contains("#strong["))
    #expect(strict.body.contains("#emph["))
    #expect(strict.body.contains("#strike["))
    #expect(!strict.body.contains("#raw("))
}

@Test func taskLabelsCannotInjectTypstAndBudgetRemainsEnforced() throws {
    let source = "- [x] #read(\"private.txt\")"
    let projection = try TypstASTExporter().render(source)
    #expect(projection.body.contains("#text(\"[x] \")"))
    #expect(!projection.body.contains("\n#read("))
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstASTExporter(maximumOutputUTF8Bytes: 12).render(source)
    }
}
