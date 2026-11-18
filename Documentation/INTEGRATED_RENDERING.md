# Integrated rendering prototype

SwiftMD's root product remains the byte-preserving Core. The local adapter
package now contains two experimental renderers over the same block processing
and SVG validation: `SwiftMDCompiler` uses Node on macOS/Linux, and
`SwiftMDJavaScriptCore` uses JavaScriptCore on Apple platforms. Both accept
trusted renderer code/configuration and return HTML plus block diagnostics.
These are not yet distributed as a remote SwiftPM package.

`Scripts/generate-adapter-mirror.py --include-locked-renderers` additionally
prepares an experimental `SwiftMDBundled` product in the generated mirror. It
downloads the exact npm tarballs referenced by `Tools/NodeDependencies/package-lock.json`,
checks their SHA-512 integrity, extracts only the original KaTeX and Pele
renderer files and their license texts, and records their SHA-256 hashes and
archive identities in `MIRROR-ORIGIN.json`. No `node_modules` or generated
renderer files are committed to the source repository. Review the bundled
artifacts and complete third-party notice obligations before publishing a mirror.

The intended consumer call is:

```swift
import SwiftMDBundled

let result = try SwiftMDIntegrated.render(
    markdown,
    svgPrefix: "unique-page-id",
    nodeExecutable: "/trusted/absolute/path/to/node" // Linux; omit on Apple
)
print(result.html)
for diagnostic in result.diagnostics { print(diagnostic.message) }
```

SwiftPM resolves SwiftGFM, Swift-Highlight and SwiftSoup in the generated
mirror; KaTeX and Pele are bundled resources, not npm dependencies installed
by the consumer. Apple platforms use JavaScriptCore and do not need Node or a
WebView. Linux requires the explicitly supplied trusted Node executable. The
generated MathML and SVG need no client-side JavaScript. Both backends have
input and output checks but no hard execution deadline or aggregate memory
limit; JavaScriptCore executes in-process, so task cancellation does not stop
running JavaScript. The SVG allowlist is not a general sanitizer or security
audit. IDs require a prefix unique across the entire composed page.

Use `math` and `mermaid` code fences. Inline math and `$$` delimiters remain
unimplemented. Backend failures preserve an escaped source block and provide a
diagnostic rather than silently succeeding. A local mirror can be generated and
tested with synthetic tags; this does not publish a mirror, tag or release.

On 18 November 2026, an iOS 27.2 simulator ran a temporary app using the actual
local `SwiftMDJavaScriptCore` product, Swift-Highlight, KaTeX 0.19.1 and Pele
1.13.0. A GFM table, highlighted Swift, MathML, SVG and an invalid-math fallback
passed together. An earlier independent JavaScriptCore probe exercised eight
Pele diagram types. These are simulator results, not physical-device or
complete security-qualification claims.
