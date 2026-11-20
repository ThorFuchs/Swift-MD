# Optional extensions

The core HTML profile is byte-identical to SwiftGFM. The separately distributed
block profile processes HTML structure and may serialize it differently. All
three renderer extensions can be used together.

| Feature | Markdown input | Renderer | Output |
| --- | --- | --- | --- |
| Syntax highlighting | A supported language code fence | Swift-Highlight | HTML spans and classes |
| Inline mathematics | `$...$`, opt-in | KaTeX | MathML |
| Display mathematics | `$$` delimiter lines, opt-in, or a `math` code fence | KaTeX | Display MathML |
| Diagrams | A `mermaid` code fence | Pele | SVG |

Use `recognizeMath: true` in the integrated API or `--markdown-math` with the
CLI's KaTeX options to recognize dollar-delimited math. The default core path
is unchanged, and `math` fences work without that option. Math is not
recognized inside code, table cells or image descriptions; unsafe raw HTML,
NUL and unclosed display blocks cause a diagnostic and an escaped source
fallback. See the [math profile and delimiter rules](https://github.com/ThorFuchs/Swift-MD/blob/main/Documentation/INTEGRATED_RENDERING.md).

Highlighting requires a host stylesheet. KaTeX and Pele run locally at
compilation time using JavaScriptCore on Apple platforms or a trusted Node
executable on Linux. The embedded MathML and SVG need no client-side
JavaScript. Each fragment placed on the same page needs its own SVG prefix.
Pele links and images are disabled.

Unrecognized or invalid blocks retain readable, escaped source and produce a
diagnostic. In CLI `--strict` mode a diagnostic prevents output. Renderer
order is deterministic; `math` and `mermaid` are reserved for their renderers.
The optional `SwiftMDDOCX` adapter produces editable Word documents: formulas
and Mermaid are retained as source rather than converted to Office Math or
images. See <doc:Security> for the trust and resource boundaries.
