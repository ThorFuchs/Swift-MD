# Changelog

## 1.0.0

The SwiftMD Core API retains byte-identical SwiftGFM rendering for the same
configuration and keeps optional renderer dependencies outside the root package.
The generated adapter distribution adds a single-call `SwiftMDBundled` API:
Swift highlighting, KaTeX block MathML and Pele diagram SVG. Apple uses
JavaScriptCore; Linux requires a trusted local Node executable. Precomputed
MathML and SVG do not require browser-side JavaScript.

This version documents its API, platform and security contracts and supplies
reproducible source/notice and independent scanner checks. Inline and `$$` math,
general sanitization, hard in-process resource limits and complete GFM
conformance are outside the contract. The adapter mirror is generated from the
reviewed SwiftMD source commit and retains the renderer and license notices.

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
