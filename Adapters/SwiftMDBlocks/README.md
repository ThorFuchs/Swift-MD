# Optional block processing and highlighting

This is a separate SwiftPM package in the SwiftMD repository. Add this package
by local path for development; remote distribution and a clean remote consumer
have not yet been qualified. `SwiftMDBlocks` supplies the structured HTML
adapter and `SwiftMDHighlight` supplies a Swift-Highlight renderer. SwiftPM
resolves Swift-Highlight even for an adapter-package consumer of only
SwiftMDBlocks. Core-only consumers use the root package and avoid all of these
additional dependencies.

```swift
import SwiftMDBlocks
import SwiftMDHighlight

let compiler = BlockCompiler(renderers: [HighlightRenderer()])
let result = try compiler.render("```swift\nlet x = \"<hello>\"\n```\n")
print(result.html)
for diagnostic in result.diagnostics { print(diagnostic) }
```

The adapter parses and reserializes the entire HTML fragment with SwiftSoup;
entity spelling, whitespace, and other serialization can change even outside
transformed blocks. With no renderers, it returns the exact core output without
parsing. Only `pre > code` is considered. The first `language-` class token
on `code`, or the first `lang` token on `pre` (for `githubPreLanguage`), is
lowercased and used as the label. Other info-string data and existing attributes
are retained by the parser. Unlabelled blocks are left alone. Raw author HTML
that matches the same shape is also processed; HTML alone cannot establish its
origin. Non-text code children are left intact with a diagnostic. HTML is not
sanitized, and unsafe raw HTML options remain the caller's responsibility.

Renderers are consulted in registration order and the first match wins. An
error leaves the block intact and returns a diagnostic rather than trying a
second renderer. A renderer returns **trusted HTML**; the caller must trust its
implementation and is responsible for sanitizing output. The API currently
supports synchronous renderers and fallback only; it does not enforce limits
or provide a strict mode. The code literal comes from decoded HTML text nodes,
not source ranges. Fidelity has only been verified for the cases in the tests;
HTML serialization cannot promise preservation for all arbitrary raw HTML.

The highlighter reserves `math` and `mermaid` for other renderers, uses the
strict explicit-language API, and checks tokens against the exact analyzed
string. Unknown languages or renderer failures retain the original code and
produce diagnostics. It serializes its own calls using one lock and cached
highlighter, but this lock does not coordinate independent Swift-Highlight
users. Upstream reports unresolved concurrency warnings; do not treat this as
a production concurrency guarantee. Regex execution is synchronous and has no
hard time or memory limit; impose input limits appropriate to the application.
Highlight classes require user-supplied CSS. No style sheet is bundled.

Run `swift test -j 4` in this directory. The currently tested host is Linux
x86_64, Swift 6.2.4; other platforms have not been validated. SwiftSoup is MIT,
Swift-Highlight Apache-2.0 with separately licensed HighlightKit and
highlight.js material; consult their LICENSE and THIRD_PARTY_NOTICES. SwiftSoup
uses MIT LRUCache and Apache-2.0 Swift Atomics. Exact source identities are in
`Package.resolved`; versions for both transitive dependencies are also pinned in
the manifest, which can cause SwiftPM unused-dependency warnings.
