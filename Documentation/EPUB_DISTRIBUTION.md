# SwiftMDEPUB distribution decision — E01

**Status:** candidate implementation, no publication yet.

Maintain the generic EPUB adapter in Swift-MD at Adapters/SwiftMDEPUB. Generate a separate standalone SwiftPM repository root (proposed public repository name Swift-MD-EPUB) from an exact committed source revision. This isolates Swift Crypto and its transitive dependencies from existing Core and bundled-renderer consumers. Do not manually duplicate or edit generated sources. Do not change existing release pins or the general adapter mirror. The separate distribution repository does not yet exist; creation/publication requires the owner and a verified candidate.

## Reproducible local proof

From a checked-out candidate revision:

    python3 Scripts/test-epub-distribution.py

The generator reads committed Git blobs, rejects unreviewed paths/modes, includes the root Apache license and existing SwiftGFM/cmark notices, and records source SHA and per-file SHA-256. It refuses an existing destination. The proof generates twice, checks byte equality and hashes, tests the package and actual EPUB fixtures, creates a disposable local Git tag 0.0.0, and resolves a separate consumer by exact version. No remote or public tag is created. For a manual candidate tree:

    python3 Scripts/generate-epub-distribution.py /tmp/SwiftMDEPUB-candidate --revision "$(git rev-parse HEAD)"

## Release firewall

Owner-reported local View Markdown shared-consumer success is encouraging, not a substitute for native logs or an upstream release gate. Prior GitHub Actions proof run 45451371716 failed on macOS/Linux with unavailable job logs. Cause unknown. Required: real standalone and version-resolved consumer tests on macOS/Linux, recorded lockfile revisions and dependency/license/security review (including Swift Crypto and transitive dependencies), EPUBCheck on both profiles, actual Books parity, provenance review, and explicit public release decision. Review current pinned dependency advisories before choosing a release version. No release or new platform certification is implied. Once published, View Markdown replaces the disposable nested-checkout bootstrap with the exact released package version, and checks existing parser pin compatibility.

Rich static XHTML (highlighting, MathML, SVG), theme-based CSS and broader EPUB feature coverage remain separate increments.
