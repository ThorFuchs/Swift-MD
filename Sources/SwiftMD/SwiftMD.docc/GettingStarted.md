# Getting started

Add the core product with Swift Package Manager:

```swift
.package(url: "https://github.com/ThorFuchs/Swift-MD.git", from: "1.1.0")
```

Add `.product(name: "SwiftMD", package: "Swift-MD")` to a target, then:

```swift
import SwiftMD

let result = try MarkdownCompiler().render("# Hello\n")
print(result.html) // <h1>Hello</h1>
```

Core uses SwiftGFM's default GFM configuration. For other options import
SwiftGFM and supply a `MarkdownConfiguration` to the compiler. Rendering
errors throw; baseline diagnostics are empty. Raw HTML and unsafe URLs are
controlled by that configuration, and the output is not sanitized.

## Add the renderers

The optional products are distributed in the generated, read-only adapter
mirror. Add the mirror alongside Core:

```swift
.package(url: "https://github.com/ThorFuchs/Swift-MD-Adapters.git", from: "1.2.0")
```

Add `.product(name: "SwiftMDBundled", package: "Swift-MD-Adapters")` to your
target. The integrated API combines syntax highlighting, KaTeX and Pele:

```swift
import SwiftMDBundled

let result = try SwiftMDIntegrated.render(
    "Inline $x^2$ and a diagram:\n\n```mermaid\nflowchart LR\nA-->B\n```\n",
    svgPrefix: "unique-page-id",
    recognizeMath: true
)
print(result.html)
for diagnostic in result.diagnostics { print(diagnostic.message) }
```

On Linux, also pass `nodeExecutable` with a trusted absolute path to Node.
Apple platforms use JavaScriptCore. Each independently rendered fragment on
the same page needs a distinct SVG prefix. See <doc:Extensions> for supported
syntax and trust boundaries, and <doc:ExampleGallery> for real outputs.
