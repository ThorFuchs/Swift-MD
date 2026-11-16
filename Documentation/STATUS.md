# Implementation status

This is an initial baseline, not the completed implementation brief. SwiftGFM
is pinned at `d1c262f42daa7a06f4612a94671e10740e26d09a`, Apache-2.0, with
cmark-gfm 0.29.0.gfm.13 at `27d942c8b0a62d192f616e5bf3578f4b6a89e180`;
its bundled C source retains the notices in its `Vendor/GitHubCMark/COPYING`.
The wrapper is Swift around a C parser, not a pure Swift parser.

The default route delegates directly to SwiftGFM with precisely the supplied
configuration. Tests compare representative inputs and options to SwiftGFM;
this is not a full reference-backend parity run. The published GFM corpus and
independent cmark-gfm fixture/reference runs are not yet imported or executed.
There is no claim of strict GFM corpus conformance.

Swift-Highlight was observed at `be6b555fed12d15af337facfc0ca4b3d8b4ba6b5`;
its README describes an HTML renderer and unresolved Linux concurrency
warnings. An optional adapter now integrates it, with its own call lock but
no guarantee covering independent upstream users. Swift-KaTeX at
`b20e2c53760b91742ce641a5c43ee999c59122b3` and Swift-Mermaid at
`2574531392677f7cf46bae7ac2191f458e61c74c` expose Apple WKWebView/PDF
renderers, not the needed Linux MathML/SVG API. Neither is a dependency. Pele,
KaTeX and a JS runtime have not been selected or integrated. SwiftSoup is
used by the optional block adapter, never by the core.
Their licensing, resource handling, security and runtime must be evaluated
before distribution. No assets are supplied.

## Integration decisions still required

SwiftGFM's read-only AST is not renderable or mutable; parse and render are
separate operations. HTML cannot distinguish an authored raw `<pre><code>`
from equivalent rendered Markdown. The opt-in adapter processes all matching HTML code blocks, including raw HTML;
its tested literal and option coverage remains incomplete. The baseline deliberately avoids HTML
postprocessing and preserves backend bytes. A naive regex or source-range
matching solution is not sufficient. `$$` is ordinary GFM input; supporting it
requires a separately specified and tested parser integration. Inline math is
also unsupported.

A full implementation still needs broader block dispatch and fallback tests,
independently optional MathML/SVG adapters, SVG sanitization
and deterministic IDs, resource limits, documentation of licenses and assets,
full fixture/reference comparisons, consumer builds and platform tests.
Linux, Apple and WASI support must be reported only after actual builds and
execution; no WASI runtime test has been performed.

## Verified in this checkout

On Linux x86_64, official `swift:6.2.4` image (digest
`sha256:3459518b2e723a7c363d0f8cfa44fc796c77ecd8c18e92fd10e6f92dd78c0b12`),
`swift test -j 4` built the package and ran 2 XCTest cases, 0 failures and
0 skips. One case makes 40 baseline comparisons across eight inputs and five
configurations; the second checks known HTML and error propagation. These are
comparisons to the Swift wrapper, not an independent C reference or corpus.
A temporary separate SwiftPM consumer using a local path to this checkout was
built and run in Debug and Release, asserting the rendered HTML. A published
remote consumer has not been tested. Container Git used the host CA bundle
for TLS verification. No macOS/iOS, WASI, or other Linux architectures were
built or executed. Swift 6.0 and 6.4.2 were not tested.

## Block adapter validation

The optional `Adapters/SwiftMDBlocks` package uses SwiftSoup 2.11.3 at
`d86f244ed497d48012782e2f59c985a55e77b3f5` and Swift-Highlight at the
commit listed above. On Linux x86_64 with Swift 6.2.4, `swift test -j 4`
executed 8 XCTest cases, 0 failures and 0 skips. They include real Swift
highlighting, text reconstruction, raw HTML policy, selected options,
priority, fallback, CRLF, repeated and empty blocks. A temporary local-path
consumer built and executed the highlighting pipeline in Debug. Remote
consumer resolution, Release, concurrency stress, full source-literal and
option matrices, other hosts and production security qualification remain
open. See the adapter README for trust, asset, serialization and dependency
constraints. The adapter package resolves Swift-Highlight even if only its
block product is selected; the root Core package does not.
