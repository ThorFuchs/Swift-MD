# SwiftMDTypst — strict semantic GFM → native Typst source (vertical slice)

This is a separate SwiftPM product of Swift-MD, modelled after SwiftMDDOCX. It does **not** alter the normal SwiftMD Markdown→HTML rendering path, does not parse HTML back to Markdown, and does not need a Typst runtime to generate source. It is directly exposed as a root SwiftMD package product and via the nested Adapters/SwiftMDTypst standalone Package.swift.

## Implemented for the initial strict profile

- SwiftGFM 1.1.0 cmark-GFM AST as the **single Markdown parsing authority**; pinned source byte and AST node/depth budgets; output size and nesting bounds.
- Headings H1–H6 with exact parsed inline formatting and PDF-label candidates **vm-0, vm-1, ...**, source ranges and an inspectable Swift heading manifest. They are snapshot-order keys aligned with ViewMarkdown's current HTML DOM outline keys, not stable IDs across arbitrary Markdown edits or raw HTML.
- Paragraphs, text literals, soft/hard breaks, emphasis, strong, strikethrough, inline code, absolute HTTP(S)/mailto links and deliberate hard refusals of ambiguous or unauthorized URLs.
- Ordinary unordered and ordered lists, including original ordered start/delimiter and nesting.
- GFM tables with original per-column alignment and typed table headers; block quotes, thematic rules and verbatim fenced code, preserving source text.
- **Trusted, opt-in TeX code-fence seam**: application-owned allowlisted math converter supplies a completed Typst math expression. No raw Typst from Markdown or model prompts. Inline math remains a separate unresolved SwiftGFM math-occurrence slot problem.
- Fail-closed on Mermaid, raw HTML, images needing a verified asset, task list checkbox semantics, footnotes without correlated AST identifiers, custom nodes, unknown nested node shapes or unsupported source/URL values.

## Important ownership split

- SwiftMDTypst produces only an AST-derived **Typst document body + HeadingRecords**.
- A separate **ResolvedPublicationPlan** owns approved fonts, page/pagination/PDF policies and Theme role bindings. Never duplicate Theme token values in this package.
- The released Swift-Typst v1.0.0 compiler, and future PDFKit ViewMarkdown app integration, are separate consumers. No MiTeX runtime.
- The HeadingRecords mirror the existing temporary vm-N WebKit outline IDs for identical parsed Heading streams. A stable cross-engine source identity and authored HTML IDs require a later explicit, shared AST->HTML/Typst projection contract.

## Verification

Run the pinned Swift Testing adapter suite:

    swift test --package-path Adapters/SwiftMDTypst

The branch-scoped workflow also calls SwiftMDTypstProof on Fixtures/gfm-proof.md, compiles its **actual Swift-emitted source** with official SHA-256-verified Typst CLI 0.15.1 and checks real PDF text and bookmark destinations. Failure to generate a document or bookmark is not treated as success.

## Limits and scope firewall

This is an **independent new adapter**, not a full production Markdown export or WebKit replacement. The 27 SwiftGFM AST kinds are exhaustively classified by a closed switch or explicit failure, not all 27 are supported yet. Math-fences rely on a separate vetted converter; math inline and Mermaid require additional asset/occurrence projection. HTML/CSS Themes and font calibration are not applied here. Reflow, pages, thumbnails, PDFKit user interactions, performance, cancellation and page content parity remain separate work.

No changes to ViewMarkdown Reader, its running Wave 07, Swift-GFM core, existing SwiftMDBundled HTML, user Markdown or third-party licensing. No automated merge. The code is a reviewable vertical slice that can be consumed by an independent ViewMarkdown research package once the Swift package is verified.
