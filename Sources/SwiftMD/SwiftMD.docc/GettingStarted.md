# Getting started

Add the core product with Swift Package Manager:

```swift
.package(url: "https://github.com/ThorFuchs/Swift-MD.git", from: "1.0.0")
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

The optional adapters and CLI currently build from a local source checkout;
the separate adapter distribution mirror has not been published. See the
repository README for a complete CLI example and the example gallery.
