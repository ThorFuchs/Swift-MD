# SwiftMDTypst v0 proof — real AST-to-Typst PDF evidence

**21 November 2026 · standalone adapter only, no production ViewMarkdown UI change**

## Verified committed source and test

- Source code SHA/commit of independently tested adapter: **7d72f32aa8c4119b1450d2e84c7ed736c551f5c4**.
- [Successful GitHub Actions #44925722007](https://github.com/ThorFuchs/Swift-MD/actions/runs/44925722007): **9/9 Swift Testing assertions** passed on Linux, root SwiftMDTypst product built, original pinned GFM Markdown source emitted to Typst via SwiftGFM 1.1.0 AST.
- The official **Typst CLI 0.15.1 (9dfd3a08)** archive was SHA-256 verified, and the actual Swift-emitted Typst source was compiled to a one-page PDF, no compiler stderr.
- PDF text and **three native outline headings/bookmark destinations** were inspected, including two identically titled headings that remained distinct.
- [Original proof artifact](https://github.com/ThorFuchs/Swift-MD/actions/runs/44925722007) under name `swiftmdtypst-ast-pdf-proof`: emitted `document.typ`, `document.pdf`, `headings.json`, compiler version, semantic verification.
- The root Swift-MD/SwiftGFM source is not modified by this exporter beyond **adding an optional SwiftPM library product**. No HTML/CSS transcode, Typst dependency at export time or external MiTeX runtime.

## Independent cross-repo consumer

The new [ViewMarkdown research PR #31](https://github.com/ThorFuchs/ViewMarkdown/pull/31) depends on this exact source revision and combines the AST adapter with ViewMarkdown's tested TeX M0/M1, typed PublicationResolver P1 and released in-process Swift-Typst v1.0.0. [Successful integrated CI #44926631715](https://github.com/ThorFuchs/ViewMarkdown/actions/runs/44926631715) produced a styled PDF with a math fraction and four named destinations `vm-0`..`vm-3`; it also passed two Apple PDFKit navigation tests on macOS.

## Explicit boundaries

The API is a **strict semantic subset**: it does not automatically project inline math, Mermaid, raw HTML, images, task checkboxes, or footnote references without trusted semantic metadata. Unknown input fails with an error and cannot silently disappear. The stable application-wide HeadingKey model, full Theme role matrix and production PDFKit reader UI are separate work. The current heading vm-N IDs are snapshot-local ordinal values matching the accepted ViewMarkdown DOM projection for the tested heading stream, not stable references across arbitrary source revisions.

Do not merge or publish automatically; owner review required. The existing SwiftMD HTML rendering behavior and GitHub cmark-GFM source remain unchanged.
