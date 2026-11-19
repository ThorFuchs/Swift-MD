# DOCX spike verification snapshot

2026-11-19, macOS 27.3 (26C5035r), arm64, Apple Swift 6.4.2:

- `swift build --package-path Adapters/SwiftMDDOCX`: passed.
- `SWIFTMDDOCX_TEST_OUTPUT=/tmp/swiftmd-example.docx swift test --package-path Adapters/SwiftMDDOCX`: six XCTest cases passed, zero failed, including tight and loose lists, paragraph spacing, table padding and invalid spacing values.
- Root `swift test -j 4`: two XCTest cases passed; the bundled cmark HTML expectation suite passed 704 cases. Two upstream-disabled examples, one `<IGNORE>` expectation, and two independent-C comparison tests were skipped; no independent C renderer was configured.
- `python3 Scripts/check-docx-fixture.py /tmp/swiftmd-example.docx`: seven ZIP parts, CRCs, XML, the settings content type and relationship, and compatibility mode `15` passed using Python's independent standard-library readers.
- `qlmanage -t -s 1200 -o /tmp /tmp/swiftmd-example.docx`: macOS Quick Look produced a thumbnail. Visual inspection showed the fixture's heading, Unicode, formatting, nested lists, ordered start, table, code and quotation.
- Microsoft Word 16.115.1 opened the initial fixture in Compatibility Mode; its saved settings specified mode `12`. A comparison with mode `15` opened without the label. The final exporter-generated fixture also opened without the label; a text edit was saved, the document closed and reopened with the edit intact, and Python verified the saved CRC, text and retained mode `15`. Heading, list and table spacing was visually inspected. Pages was not tested. This is not an Office compatibility certification. See [Microsoft compatibilityMode specification](https://learn.microsoft.com/en-us/openspecs/office_standards/ms-docx/90138c4d-eb18-4edc-aa6c-dfb799cb1d0d).

GitHub-hosted Linux CI on the original DOCX commit `49ace247` passed both
DOCX jobs, including SwiftPM tests and the independent archive check; core,
Linux archive and integration jobs also passed. CI for subsequent changes
must be evaluated on their actual commit. The fixture is independently authored
for this spike.
