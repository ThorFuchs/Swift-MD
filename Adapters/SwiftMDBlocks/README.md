# Experimental block adapters

`SwiftMDBlocks` is an opt-in HTML profile: it parses and reserializes the
SwiftGFM HTML with SwiftSoup and processes matching `pre > code` elements.
With no renderers it bypasses parsing and returns the exact core bytes. Source
provenance cannot be established from HTML, so author-written matching raw HTML
is processed too. Nested non-text code content is retained with a diagnostic.
This profile does not sanitize Markdown or raw HTML. A trusted renderer is a
trust boundary. Renderers run in registration order and the first match wins;
errors preserve the original escaped code and return a diagnostic.

`SwiftMDHighlight` reserves `math` and `mermaid`, validates the highlighter's
UTF-16 token ranges and source identity, and serializes its own calls. Its lock
does not coordinate independent Swift-Highlight users; upstream concurrency
warnings remain relevant. Highlighting has no hard execution time limit.

`SwiftMDKaTeXNode` accepts `math` fences. It uses JSON over stdin, KaTeX's
MathML-only display mode, `trust: false`, strict errors, `maxExpand: 500` and
`maxSize: 10`. `SwiftMDPeleNode` accepts `mermaid` fences, disables links and
images, fixes the Gantt clock and derives IDs from a caller-specified page-unique
prefix and block index. SVG is accepted only through a deliberately restrictive
XML, element, attribute and CSS allowlist, and inserted byte for byte after
validation. Presentation values use a restricted CSS grammar that rejects
escapes, comments, URLs and unknown functions; geometry attributes use narrow
numeric grammars. The only permitted internal references are root ARIA links
to uniquely named, direct-child `title` and `desc` elements for that block.
Unknown constructs and other references are rejected, preserving the original
block. Validation rejects fragments over 2,000,000 UTF-8 bytes. The allowlist and Pele filtering are not a general SVG sanitizer
or a security audit; host CSS and raw HTML remain separate trust boundaries.

The Node executable and module path are trusted configuration. Both adapters
reject input above 16,384 UTF-8 bytes and check output size after process exit.
They do **not** enforce a hard time, memory, disk or live output limit. Run them
in an appropriately constrained worker when handling untrusted material.
The optional package currently resolves Swift-Highlight even for other products;
the root Core package avoids that dependency. It requires private Swift-Highlight
access at the pinned revision. SwiftPM remote adapter distribution is not yet
available. No `$$` or inline mathematics is implemented.
