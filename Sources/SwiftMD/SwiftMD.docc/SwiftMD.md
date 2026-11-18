# ``SwiftMD``

Compile Markdown to HTML with the pinned SwiftGFM and cmark-gfm backend.

## Overview

SwiftMD's core provides a synchronous Swift interface to SwiftGFM's C-backed
Markdown renderer. With the same configuration it returns precisely the same
HTML bytes as SwiftGFM. It requires neither Node nor a browser.

```swift
import SwiftMD

let result = try MarkdownCompiler().render("# Hello, SwiftMD\n")
print(result.html)
```

Optional, separately built adapters add Swift syntax highlighting, KaTeX
MathML, and Pele SVG. Node runs during compilation for the latter two; the
resulting document does not need JavaScript to display those fragments.

## Topics

### Guides

- <doc:GettingStarted>
- <doc:Extensions>
- <doc:ExampleGallery>
- <doc:Security>

### Core API

- ``MarkdownCompiler``
- ``MarkdownResult``
