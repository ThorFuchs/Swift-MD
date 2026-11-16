# SwiftMD

SwiftMD is an early Swift 6 library for composing Markdown-to-HTML rendering.
The core is a baseline facade over SwiftGFM and its vendored cmark-gfm C
backend. An optional separate package provides structured block processing and
Swift-Highlight integration; see [its README](Adapters/SwiftMDBlocks/README.md).
MathML, Mermaid and `$$` mathematics are not implemented. No conformance
certification is claimed.

## Use

Add this repository as a Swift package dependency once an appropriate commit
is available. The `SwiftMD` product depends on `SwiftGFM`; it does not depend
on a JavaScript runtime or Apple UI frameworks.

```swift
import SwiftMD
import SwiftGFM

let compiler = MarkdownCompiler(configuration: .gfm)
let result = try compiler.render("# Hello\n")
print(result.html) // <h1>Hello</h1> followed by a newline
```

`MarkdownCompiler` takes a SwiftGFM `MarkdownConfiguration` and returns the
unmodified HTML fragment and an empty diagnostics array. Errors from SwiftGFM
are propagated. The compiler is a `Sendable` value; SwiftGFM serializes its C
backend calls. Configuration, URL handling, raw HTML, and resource limits are
those of SwiftGFM. Output is not a sanitizer, especially with unsafe HTML
allowed. No assets are produced. No hard time or memory limits are added.

Run `swift test` from the repository root. Swift language mode 6 is required.
The manifest minimum of Swift 6.0 follows the pinned dependency; it is not a
claim that all supported configurations have been tested with 6.0. See
[implementation status](Documentation/STATUS.md) for verification and gaps.
