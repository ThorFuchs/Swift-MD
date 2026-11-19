# DOCX spike verification snapshot

2026-11-19, macOS 27.3 (26C5035r), arm64, Apple Swift 6.4.2:

- `swift build --package-path Adapters/SwiftMDDOCX`: passed.
- `SWIFTMDDOCX_TEST_OUTPUT=/tmp/swiftmd-example.docx swift test --package-path Adapters/SwiftMDDOCX`: five XCTest cases passed, zero failed.
- Root `swift test -j 4`: two XCTest cases passed; the bundled cmark HTML expectation suite passed 704 cases. Two upstream-disabled examples, one `<IGNORE>` expectation, and two independent-C comparison tests were skipped; no independent C renderer was configured.
- `python3 Scripts/check-docx-fixture.py /tmp/swiftmd-example.docx`: six ZIP parts, CRCs, XML and internal relationship targets passed using Python's independent standard-library readers.
- `qlmanage -t -s 1200 -o /tmp /tmp/swiftmd-example.docx`: macOS Quick Look produced a thumbnail. Visual inspection showed the fixture's heading, Unicode, formatting, nested lists, ordered start, table, code and quotation.
- Word is installed, but its automated UI could not be reached; opening or editing the file in Word was **not** verified. Pages was not tested. This is not an Office compatibility certification.

No Linux runtime result is claimed by this snapshot. A Linux SwiftPM test and
independent archive check are configured in CI; a configured job is not a
hosted result. The fixture is independently authored for this spike.
