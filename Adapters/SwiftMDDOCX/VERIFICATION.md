# DOCX spike verification snapshot

2026-11-19, macOS 27.3 (26C5035r), arm64, Apple Swift 6.4.2:

- `swift build --package-path Adapters/SwiftMDDOCX`: passed.
- `SWIFTMDDOCX_TEST_OUTPUT=/tmp/swiftmd-example.docx swift test --package-path Adapters/SwiftMDDOCX`: six XCTest cases passed, zero failed, including tight and loose lists, paragraph spacing, table padding and invalid spacing values.
- Root `swift test -j 4`: two XCTest cases passed; the bundled cmark HTML expectation suite passed 704 cases. Two upstream-disabled examples, one `<IGNORE>` expectation, and two independent-C comparison tests were skipped; no independent C renderer was configured.
- `python3 Scripts/check-docx-fixture.py /tmp/swiftmd-example.docx`: six ZIP parts, CRCs, XML and internal relationship targets passed using Python's independent standard-library readers.
- `qlmanage -t -s 1200 -o /tmp /tmp/swiftmd-example.docx`: macOS Quick Look produced a thumbnail. Visual inspection showed the fixture's heading, Unicode, formatting, nested lists, ordered start, table, code and quotation.
- Microsoft Word 16.115.1 opened the original fixture in Compatibility Mode. A text edit was saved, the document closed and reopened, and the edit was still present; Python independently checked the saved archive CRC and edited text. The updated fixture also opened in Word and its heading, list and table spacing was visually inspected. Pages was not tested. This is not an Office compatibility certification.

GitHub-hosted Linux CI on the original DOCX commit `49ace247` passed both
DOCX jobs, including SwiftPM tests and the independent archive check; core,
Linux archive and integration jobs also passed. CI for subsequent changes
must be evaluated on their actual commit. The fixture is independently authored
for this spike.
