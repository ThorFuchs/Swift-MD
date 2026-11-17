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
They do **not** themselves enforce a hard time, memory, disk or live output limit.
On Linux, `Scripts/run-linux-constrained.sh` is an optional outer worker: GNU
`timeout` kills the process group at a deadline and `prlimit` applies address-space
and individual file-size limits to each process. This limits the CLI and its Node
children, not their aggregate memory, and descendants that leave the process group
can escape the timeout. It is not a sandbox. V8 reserves virtual address space,
so too-small address-space limits can prevent Node from starting. Use cgroups and
an OS sandbox for aggregate memory and stronger isolation.
The optional package currently resolves Swift-Highlight even for other products;
the root Core package avoids that dependency. Swift-Highlight is pinned to its
public 1.0.0 tag (commit 326a0085c05931b868f5bff084d51eca7584aad7). SwiftPM remote adapter distribution is not yet
available. No `$$` or inline mathematics is implemented.
