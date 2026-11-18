# SwiftMD example gallery

These independently written examples show actual SwiftMD CLI output. Each links
to its Markdown, generated HTML fragment and Chrome screenshot. The screenshots
use [preview.css](preview.css), which is not included in compiler output;
appearance depends on the browser, fonts and host stylesheet. JavaScript was
disabled while capturing these previews.

| Example | Markdown | HTML | Preview |
| --- | --- | --- | --- |
| GFM tables and tasks | [Source](Markdown/01-gfm.md) | [HTML](HTML/01-gfm.html) | [Screenshot](Images/01-gfm.png) |
| Swift highlighting | [Source](Markdown/02-highlight.md) | [HTML](HTML/02-highlight.html) | [Screenshot](Images/02-highlight.png) |
| Block mathematics | [Source](Markdown/03-math.md) | [HTML](HTML/03-math.html) | [Screenshot](Images/03-math.png) |
| Mermaid diagram | [Source](Markdown/04-diagram.md) | [HTML](HTML/04-diagram.html) | [Screenshot](Images/04-diagram.png) |
| Combined | [Source](Markdown/05-combined.md) | [HTML](HTML/05-combined.html) | [Screenshot](Images/05-combined.png) |

![Combined example](Images/05-combined.png)

### GFM tables and tasks

![GFM example](Images/01-gfm.png)

### Swift highlighting

![Swift highlighting example](Images/02-highlight.png)

### Block mathematics

![MathML example](Images/03-math.png)

### Mermaid diagram

![Mermaid SVG example](Images/04-diagram.png)

From the repository root, after `npm ci --ignore-scripts --prefix Tools/NodeDependencies`:

```sh
swift build --package-path Tools/SwiftMDCLI
python3 Scripts/render-examples.py --binary Tools/SwiftMDCLI/.build/debug/swift-md \
  --node "$(command -v node)" --check
```

Omit `--check` to update the HTML. Add
`--chrome '/path/to/Google Chrome'` to recapture screenshots. Images can vary
with browser and fonts; inspect them visually after updating. The executable and
Node module paths must be trusted. The optional adapters are experimental.
