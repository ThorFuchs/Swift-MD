# SwiftMDExport — shared output support (experimental)

Standalone Swift 6.0 package in Swift-MD, no remote dependencies. Extracted from ViewMarkdown PR #69 (7b47b165). Foundation-only generated-page HTML/WebArchive/MHTML/WARC packaging, deterministic stored ZIP, one-based page selection and pixel geometry. No rendering, file access, network capture, UI or resource discovery. WebPageExport accepts trusted admitted HTML/CSS and matching caller-owned bytes; caller owns sanitization and codec validation. Duplicate/invalid asset indices fail. Existing synthetic locations remain stable. WARC software identifier is SwiftMDExport. Archive replay not certified.

Run swift test and python3 Scripts/prove-web-page-export.py from this package. No release/mirror changes. Native bitmap/PDF processing remains a separate boundary.
