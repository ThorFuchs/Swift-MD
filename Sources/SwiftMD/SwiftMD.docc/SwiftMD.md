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

Optional adapters add Swift syntax highlighting, KaTeX MathML, Pele SVG and
an experimental editable DOCX projection. Apple platforms use JavaScriptCore
for KaTeX and Pele; Linux uses a configured local Node process. The resulting
HTML needs no client-side JavaScript to display MathML or SVG.

## Topics

### Guides

- <doc:GettingStarted>
- <doc:Extensions>
- <doc:ExampleGallery>
- <doc:Security>

### Core API

- ``MarkdownCompiler``
- ``MarkdownResult``
