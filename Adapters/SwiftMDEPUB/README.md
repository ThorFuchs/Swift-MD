# SwiftMDEPUB — experimental static EPUB export profile

An optional SwiftMD-family adapter projecting the typed SwiftGFM 1.1.0 AST into a reflowable, static XHTML publication with resources, then serializing an EPUB 3.3-oriented OCF ZIP. It shares the Markdown parser pin of SwiftMD Core, rather than reparsing rendered HTML. It has no UI, database, filesystem/network access, Node, browser or ZIP subprocess. This candidate is not a published release or a certification of EPUB compliance.

```swift
import Foundation
import SwiftMDEPUB

let source = Data("# Hello\n\n**SwiftMD**".utf8)
let exporter = EPUBExporter()

let snapshot = try exporter.compile(
    source, title: "Hello", language: "en"
)
let reading = try exporter.render(snapshot)
let archive = try exporter.render(snapshot, profile: .includingSource)

// I/O is a caller responsibility.
try reading.write(to: URL(fileURLWithPath: "hello.epub"), options: .atomic)
```

The default reading profile excludes original Markdown and internal JSON metadata. The explicit source-inclusive profile uses OPF metadata-linked resources rather than spine entries. It retains the original bytes (including BOM and line endings) and a versioned resource manifest with SHA-256/length. Including original source can disclose hidden text, comments and original media paths; choose that profile deliberately. This is not an EPUB importer. The format of the auxiliary metadata and linked-resource conventions remain experimental pending EPUBCheck and external reader checks.

## Scope and trust boundary

Single XHTML chapter, semantic headings, paragraphs, emphasis/strong/strikethrough, nested and ordered lists, quotes, rules, aligned GFM tables, escaped inline and block code, HTTPS hyperlinks and explicit snapshot-local `#vm-N` heading links. Flat navigation in source order, with heading levels kept in XHTML and manifest; heading-free content uses the spine title. No promise of anchor stability across edits. No generic slug resolution, footnotes, task items, raw HTML, MathML, SVG, Mermaid or highlighting in this initial static profile. Dollar text stays literal. Unsupported recognized constructs fail closed.

CapturedRaster inputs must be separately decoded, type-checked and authorized by the caller. The adapter does not interpret a destination as permission or attempt to retrieve it; it rewrites admitted bytes to generated UUID paths. Repeated destinations reuse their bound resource. Missing images are explicit and prevent strict EPUB export. The public low-level writer trusts validated compiler-produced XHTML/CSS, not arbitrary externally assembled content. No script, custom CSS, fonts, remote subresources or general archive reading. Budgets are documented by the source and cover input, copied AST, output and resources, not C parser memory/time. No Apple-only dependency in the export target: SHA-256 uses Apple's Swift Crypto portable API, not a handwritten implementation.

## Distribution and gates

Source package: `Adapters/SwiftMDEPUB`. Run with a Swift 6.0+ toolchain; platform minimums are candidate declarations, not native coverage claims. Exact SwiftGFM 1.1.0 (same as Core) and Swift Crypto 4.2.0 (`6f70fa9eab24c1fd982af18c281c4525d05e3095`, tag verified) are initial pins. Swift Crypto 4.2.0 is a compatibility choice, not a latest-version or security certification. Resolve and review transitive dependencies, lockfile and third-party notices before distribution. The root SwiftMD package and generated adapter mirror are deliberately unchanged in this extraction draft; no new dependency is imposed on existing Core, Typst, DOCX or renderer consumers. Future mirror integration must follow the existing generator and provenance policy and test an actual clean versioned consumer. Do not hand-edit the generated mirror or publish tags from this proof.

The generic publication model, compiler and OCF writer originate in a same-owner Apache-2.0 application prototype and are moved toward this shared adapter with the owner's authorization. Application persistence, capture, user data, screenshots and UI remain outside this source package. A real Apple Books visual proof exists for the precursor, not this extracted candidate. The precursor must be replaced by the accepted shared library in its consumer after parity tests; do not maintain two evolving compilers.

```sh
cd Adapters/SwiftMDEPUB
EVIDENCE="$(mktemp -d /tmp/swiftmdepub.XXXXXX)"
SWIFTMDEPUB_TEST_OUTPUT="$EVIDENCE" swift test
python3 verify_reference.py "$EVIDENCE"
# If EPUBCheck is installed:
epubcheck "$EVIDENCE/reference-reading.epub"
epubcheck "$EVIDENCE/reference-source.epub"
# macOS:
open -a Books "$EVIDENCE/reference-reading.epub"
```

The tests cover the actual reference Markdown, media closure, source bytes, safety, manifests, profile distinction, deterministic export of a fixed snapshot and known SHA-256. The independent Python check inspects ZIP CRC, OCF, XML, heading targets, visible content and exact source bytes. It does not replace EPUBCheck. Native and Linux builds/tests, full EPUBCheck, actual reader parity, dependency review and distribution proof remain required. No test pass for the extracted candidate is claimed yet.
