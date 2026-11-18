# Optional extensions

The core HTML profile is byte-identical to SwiftGFM. The separate experimental
block profile processes the HTML structure and may serialize it differently.
All three extensions can be used together.

| Feature | Markdown input | Renderer | Output |
| --- | --- | --- | --- |
| Syntax highlighting | A supported language code fence | Swift-Highlight | HTML spans and classes |
| Block mathematics | A `math` code fence | KaTeX on Node | Display MathML |
| Diagrams | A `mermaid` code fence | Pele on Node | SVG |

Highlighting requires a stylesheet supplied by the host. KaTeX and Pele run
locally at compilation time. Their embedded MathML and SVG do not require
client-side JavaScript. Node and module paths must be trusted absolute paths.
The caller must choose a page-unique SVG prefix when separately rendered
fragments share a page. Pele links and images are disabled.

Unrecognized or invalid blocks retain readable, escaped source and produce a
diagnostic. In CLI `--strict` mode a diagnostic prevents output. The renderer
order is deterministic; `math` and `mermaid` are reserved for their renderers.
Inline math and `$$` delimiters are not implemented. See the repository's
example gallery for inputs, actual HTML and browser screenshots.
