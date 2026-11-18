# Security and resource boundaries

Markdown, code, TeX and diagram source may be untrusted. Neither SwiftGFM HTML
nor the optional block profile is a general-purpose sanitizer. Enabling raw
HTML is an explicit trust decision. Since the block profile operates on HTML,
author-written matching `pre > code` elements can also be processed.

Third-party renderer HTML is trusted. Pele SVG is checked against a restrictive
fail-closed allowlist before byte-preserving insertion, but this is not an
independent audit or a general SVG sanitizer. Host HTML, CSS and the page-unique
SVG prefix are separate trust boundaries.

Node adapters limit input and check output size after process exit. They do not
themselves impose a hard execution deadline or aggregate memory limit. Optional
Linux supervised and systemd workers provide documented additional controls;
they require host-specific validation and are not complete security sandboxes.
See `Documentation/PROCESS_ISOLATION.md` in the repository for exact limits.
