# Third-party notices

Swift-Highlight contains HighlightKit by Phrase (MIT), revision
`524c185b0553756498c1b6a1765e8d119c4623a6`. The complete original
license is in `Licenses/HighlightKit-MIT.txt`. HighlightKit ports
highlight.js 11.11.1, commit `08cb242e7d4aee787114eb04cc7ab18314d82f92`.
Its engine semantics, language grammars, fixtures and GitHub themes derive
from highlight.js. Its full BSD-3-Clause license is in
`Licenses/highlight.js-BSD-3-Clause.txt`. The Xcode themes originated in
HighlightKit; adaptive variants remain included. Both notices and license
texts must accompany source and binary distributions. The Apache-2.0 root
license applies to new project contributions, not as a replacement for the
licenses of imported material.

The fixture corpus is imported unchanged from HighlightKit. A byte-level inventory
against the pinned highlight.js checkout found 354 exact matches and 21 files
without exact matches. Fifteen of those have high textual similarity to a
reference fixture and two extend a reference fixture. The remaining four are
byte-identical to files from later highlight.js commits, each with the same
BSD-3-Clause root license; exact revisions appear in
`Documentation/FIXTURE-PROVENANCE.md`. Similarity does not prove attribution. Exact matches
do not by themselves prove the ownership of all contributed material. In particular,
`Tests/HighlightKitTests/Fixtures/xml/document-type-variations.code.txt`
contains a Walt Disney Company copyright string and a Donald Duck reference.
The Erlang fixtures `erlang/sigil.code.txt` and
`erlang/triple_quote_string.code.txt` include attributed quotations from
Dorothy L. Sayers and Terry Pratchett; both match upstream highlight.js test
files. The 17 non-identical-to-highlight.js fixtures and these three examples
also match the pinned HighlightKit revision byte-for-byte. Before distribution,
review the provenance and any additional rights in quoted material.
This document does not assert that such an audit is complete.
