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
warnings. It is not integrated. Swift-KaTeX at
`b20e2c53760b91742ce641a5c43ee999c59122b3` and Swift-Mermaid at
`2574531392677f7cf46bae7ac2191f458e61c74c` expose Apple WKWebView/PDF
renderers, not the needed Linux MathML/SVG API. Neither is a dependency. Pele,
KaTeX, an HTML parser and a JS runtime have not been selected or integrated.
Their licensing, resource handling, security and runtime must be evaluated
before distribution. No assets are supplied.

## Integration decisions still required

SwiftGFM's read-only AST is not renderable or mutable; parse and render are
separate operations. HTML cannot distinguish an authored raw `<pre><code>`
from equivalent rendered Markdown. A structured HTML adapter therefore needs
an explicit provenance policy, exact literal handling, option coverage and a
security contract before activation. The baseline deliberately avoids HTML
postprocessing and preserves backend bytes. A naive regex or source-range
matching solution is not sufficient. `$$` is ordinary GFM input; supporting it
requires a separately specified and tested parser integration. Inline math is
also unsupported.

A full implementation still needs structured block dispatch and fallback,
real independently optional highlight/MathML/SVG adapters, SVG sanitization
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
