# Changelog

## 0.1.0

Initial release of the SwiftMD core library. With the same configuration it
returns byte-identical SwiftGFM HTML. The root SwiftPM product depends on the
public SwiftGFM 1.0.1 release and does not require Node or a browser.

The source checkout also contains experimental block adapters and a CLI for
Swift-Highlight, KaTeX MathML and Pele SVG. These are not yet published as a
separate SwiftPM adapter mirror or CLI archive. The output can display its
precomputed MathML and SVG without client-side JavaScript. See the README,
extension guide and security documentation for trust and platform boundaries.

Inline and `$$` mathematics are not implemented. The published GFM corpus has
known differences from the pinned cmark backend; full conformance is not claimed.
