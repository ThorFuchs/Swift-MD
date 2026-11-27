// SPDX-License-Identifier: Apache-2.0
import Foundation
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

@Test func imageHooksUseOnlyExactSlotsAndLeaveOtherStrictnessInForce() throws {
    let source = """
    # Report

    Before ![Captured **image**](capture.png) after.

    ![Standalone](capture.png)

    ![Missing](unselected.png)

    ![External](https://example.invalid/image.png)
    """
    let projection = try TypstImageProjection(slots: [Data("capture.png".utf8): 4])
    let exporter = TypstASTExporter(imageProjection: projection)
    let result = try exporter.render(source)
    #expect(result.body.contains(#"#vm-image(4, alt: "Captured image", block: false)"#))
    #expect(result.body.contains(#"#vm-image(4, alt: "Standalone", block: true)"#))
    #expect(result.body.contains(#"#vm-missing-image("Missing", block: true)"#))
    #expect(result.body.contains(#"#vm-missing-image("External", block: true)"#))
    #expect(result.body.contains("#text(\"Before \")") && result.body.contains("#text(\" after.\")"))
    #expect(!result.body.contains("capture.png") && !result.body.contains("example.invalid"))
    #expect(result.degradations == [.imageAsPlaceholder])
    #expect(throws: TypstProjectionError.self) {
        _ = try exporter.render("[File](file:///unselected.txt)")
    }
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstImageProjection(slots: [Data("capture.png".utf8): 512])
    }
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
    #expect(Set(result.degradations) == [.linkAsText, .imageAsPlaceholder, .htmlAsText, .taskListAsText, .mermaidAsCode])
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


@Test func optInListHooksPreserveTaskStateStartDelimiterAndNestedAST() throws {
    let source = """
    # Plan

    3) [x] Checked **one**
    4) [ ] Unchecked
    5) Regular
       - Nested ordinary
       - [x] Nested checked

    - Ordinary first
    - [ ] Task second
    - Ordinary third

    ## End
    """
    let result = try TypstASTExporter(listProjection: .semanticItemHooks).render(source)
    #expect(result.headings.map(\.key) == ["vm-0", "vm-1"])
    #expect(result.degradations.isEmpty)
    #expect(result.body.contains("#vm-ordered-list(start: 3, numbering: \"1)\", tight: true"))
    #expect(result.body.contains("#vm-bullet-list(tight:"))
    #expect(result.body.contains("(checked: true, body: ["))
    #expect(result.body.contains("(checked: false, body: ["))
    #expect(result.body.contains("(checked: none, body: ["))
    #expect(result.body.contains("#strong["))
    #expect(result.body.contains("#text(\"Nested checked\")"))
    #expect(!result.body.contains("#text(\"[x] \")"))
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstASTExporter().render(source)
    }
}

@Test func semanticListHooksAreOptInAndDoNotBroadenOtherAdmission() throws {
    let plain = "3. one\n4. two\n\n- alpha\n- beta"
    let original = try TypstASTExporter().render(plain)
    #expect(original.body == (try TypstASTExporter(listProjection: .native).render(plain)).body)
    #expect(original.body.contains("#enum(start: 3, numbering: \"1.\""))
    let hooks = try TypstASTExporter(listProjection: .semanticItemHooks).render(plain)
    #expect(hooks.body.contains("checked: none"))
    #expect(!hooks.body.contains("checked: true"))
    for input in ["![image](file:///private/file)", "<script>bad</script>",
                  "- [x] [bad](file:///private/file)", "~~~mermaid\ngraph TD; A-->B\n~~~"] {
        #expect(throws: TypstProjectionError.self) {
            _ = try TypstASTExporter(listProjection: .semanticItemHooks).render(input)
        }
    }
    #expect(throws: TypstProjectionError.self) {
        _ = try TypstASTExporter(maximumOutputUTF8Bytes: 16,
            listProjection: .semanticItemHooks).render("- [x] Text")
    }
}


@Test func semanticListHookIdentityIsUniquePreorderAndDoesNotLeakIntoNativeMode() throws {
    let source = """
    - First
      - [x] Nested
        - [ ] Deeper
    - [ ] Second

    3) Third
    4) [x] Fourth

    > - [x] In quote
    """
    let exporter = TypstASTExporter(listProjection: .semanticItemHooks)
    let one = try exporter.render(source).body
    #expect(one == (try exporter.render(source)).body)
    for id in 0..<5 {
        #expect(one.components(separatedBy: "list-id: \(id),").count == 2)
    }
    #expect(!one.contains("list-id: 5,"))
    let native = try TypstASTExporter(unsupportedContentPolicy: .readerPreview).render(source)
    #expect(!native.body.contains("list-id:"))
    #expect(native.degradations.contains(.taskListAsText))
}
