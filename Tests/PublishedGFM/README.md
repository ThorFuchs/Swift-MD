# Independently published GFM specification snapshot

`gfm-0.29.html` is the unmodified HTML downloaded from
https://github.github.com/gfm/ on 17 November 2026. The document identifies
itself as GFM 0.29 (2019-04-06), based on the CommonMark Spec by John
MacFarlane, and licenses the specification under CC BY-SA 4.0. The full license
text is retained in `../SwiftMDTests/Fixtures/cmark-gfm/LICENSE`.

SHA-256: `b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220`.
This independent published HTML snapshot is not the bundled cmark-gfm fixture
corpus. `Scripts/test-published-gfm.py` extracts all 677 visible example pairs,
decodes their HTML text and changes the displayed tab marker `→` to a tab as
specified in the document. It compares exact output bytes from the standard
SwiftMD GFM profile with `allowUnsafeHTML` enabled and all five GFM extensions,
including tagfilter. This is a test configuration, not a sanitizer recommendation.

The published expected HTML sometimes shows raw disallowed tags and serializes
checkbox inputs differently from cmark-gfm with this option set. Therefore
byte differences need individual interpretation; this test does not establish
semantic equivalence or full GFM conformance. It exits nonzero for any mismatch
and is deliberately separate from the passing cmark fixture and C parity gate.
