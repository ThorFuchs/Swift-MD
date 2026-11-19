# External rights review: SwiftMD 1.0 candidate

**Historical packet:** This document describes the earlier candidate that
resolved SwiftSoup remotely. The current candidate vendors only its library
sources and omits its test corpus, as described in
[the updated source audit](../ThirdPartyLicenses/SwiftSoup-SOURCE-AUDIT.md).
It remains here as provenance for the earlier review, not as a description of
the current mirror's dependencies.

This is an evidence packet for a qualified external reviewer. It does not
decide the governing law, copyright ownership, license compliance, or whether
any material infringes rights. The reviewer should assess the actual intended
distribution and supply a written disposition before the adapter release.

## Distribution being reviewed

* `ThorFuchs/Swift-MD` is a public source repository; its current `0.1.0` tag
  predates this candidate. The proposed 1.0 source is in draft PR
  [#1](https://github.com/ThorFuchs/Swift-MD/pull/1). Earlier SwiftMD Git
  history contains two cmark-gfm fixture files removed from the present source
  snapshot. The historical rights question was not resolved by their removal.
* A separately generated public SwiftPM adapter mirror is planned. It contains
  SwiftMD adapter and CLI sources, notices, and byte-verified KaTeX 0.19.1 and
  Pele 1.13.0 JavaScript resources. The mirror is a distribution artifact;
  SwiftMD remains the only source repository. No mirror is published yet.
* SwiftPM separately fetches SwiftGFM 1.0.1, Swift-Highlight 1.0.1, SwiftSoup
  2.11.3 and their resolved dependencies. A source package fetched by SwiftPM
  may contain test material beyond the target that is compiled or embedded in
  an application. Please distinguish the mirror's own files, upstream source
  checkouts, Git history and any binary or application distribution.

## Specific SwiftSoup question

The pinned SwiftSoup 2.11.3 source is commit
[`d86f244ed497d48012782e2f59c985a55e77b3f5`](https://github.com/scinfu/SwiftSoup/tree/d86f244ed497d48012782e2f59c985a55e77b3f5).
Its package declares an MIT root license and its library target uses `Sources`.
Its source snapshot also includes six saved third-party web pages in
[`Tests-macOS/corpus`](https://github.com/scinfu/SwiftSoup/tree/d86f244ed497d48012782e2f59c985a55e77b3f5/Tests-macOS/corpus).
The generated SwiftMD mirror does not copy that corpus, but a SwiftPM consumer
resolving the unmodified upstream package fetches its source separately.

[`Google.html`](https://github.com/scinfu/SwiftSoup/blob/d86f244ed497d48012782e2f59c985a55e77b3f5/Tests-macOS/corpus/Google.html)
has Git blob `a215fa8a4324caae3841af5c78c600c265a877bc` and SHA-256
`094d6a66d4540a9539eb02315b830bc7219a4e141893d4dd5f5757125c7fd46c`.
It includes a comment identifying Math.uuid.js by Robert Kieffer and stating
dual MIT/GPL licensing, another identifying Closure Authors and MochiKit, and
material presented as a Google page. The root MIT license alone does not
identify the terms of every piece of this test page. SwiftSoup 2.14.4 still
contains the same six corpus paths and the identical Google blob.

Please determine, for the intended jurisdictions and distribution methods:

1. Which rights and license terms apply to the six fixtures and their embedded
   material, and what evidence or notices are needed for each relevant use?
2. What responsibilities, if any, arise from a generated package depending on
   the upstream SwiftSoup Git URL, versus copying the source, publishing an
   archive or distributing an application binary? Does the answer differ for a
   consumer's own SwiftPM checkout or the pre-existing upstream Git history?
3. If the evidence is insufficient, would a separately verified source
   distribution that contains the needed SwiftSoup library files and notices
   but omits the six test pages address the issue? Identify any further
   attribution, licensing, source, compatibility or distribution requirements.
4. Which other corpus pages, embedded notices, source archives or historical
   files require review before the proposed 1.0 distributions are shipped?

## Other evidence for review

The 17 Swift-Highlight fixtures previously differing from one pinned
highlight.js revision match the original HighlightKit import. Fifteen match
earlier-dated highlight.js revisions byte for byte; the other two match after
removing an initial UTF-8 BOM. The comparison and upstream license-byte checks
are reproducible with `Scripts/audit-highlight-fixtures.py`. The original
upstream inventory is in
[Swift-Highlight's provenance report](https://github.com/ThorFuchs/Swift-Highlight/blob/71d23c52a4afe154acdcc3b8aee968f0bf1b8564/Documentation/FIXTURE-PROVENANCE.md).
These matches do not independently establish every contributor's rights.

The bundled KaTeX and Pele notices, including the identified React, font,
esbuild, Mermaid and d3 reference notices, are inventoried in
`ThirdPartyLicenses/`. Pele describes a Mermaid lexer port and d3-related
Gantt behavior without naming exact upstream revisions. The reference licenses
are retained conservatively; their exact use and the completeness of notices
should be reviewed without treating reference commits as proven source origins.

Separate ScanCode 33.0.0rc1 reports for the mirror, SwiftMD, SwiftGFM,
Swift-Highlight and SwiftSoup/LRUCache/swift-atomics source snapshots were
generated locally. They are automated detection evidence, not a legal
conclusion; scan scope and known false matches are documented in
[SECURITY_LICENSE_REVIEW.md](SECURITY_LICENSE_REVIEW.md). Reports contain
local paths and should be inspected before forwarding externally. The source
snapshots scanned do not include older Git history.

## Requested written result

Please identify the reviewed commit/tag and files, any assumptions and missing
evidence, the approved distribution scope and required notices or changes.
If clearance is limited or unavailable, identify the smallest specific remedy
and whether it covers the actual SwiftPM source-fetch path. This packet itself
does not grant permission to publish or waive the project's release gates.
