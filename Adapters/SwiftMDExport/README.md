# SwiftMDExport — shared output support (experimental)

Standalone Swift 6.0 package in Swift-MD, no remote dependencies. Extracted from ViewMarkdown PR #69 (7b47b165). Foundation-only generated-page HTML/WebArchive/MHTML/WARC packaging, deterministic stored ZIP, one-based page selection and pixel geometry. No rendering, file access, network capture, UI or resource discovery. WebPageExport accepts trusted admitted HTML/CSS and matching caller-owned bytes; caller owns sanitization and codec validation. Duplicate/invalid asset indices fail. Existing synthetic locations remain stable. WARC software identifier is SwiftMDExport. Archive replay not certified.

Run swift test and python3 Scripts/prove-web-page-export.py from this package. No release/mirror changes. Native bitmap/PDF processing remains a separate boundary.

## Optional native PDF raster adapter

On platforms providing Core Graphics, ImageIO and UniformTypeIdentifiers, PDFPageRasterizer plans selected crop-box dimensions and renders white sRGB PNG/JPEG from the supplied PDF. No AppKit or View Markdown dependency. 64 pages, 16M pixels per page (40M for a single 600 DPI page), 120M aggregate pixels, 64 MiB encoded bytes. Plan reports actual page numbers, geometry, total pixels and largest raw 4-byte pixel buffer, not a predicted compressed size or peak-process-memory guarantee. Render preflights the entire selection before encoding, preserves original numbering and checks cancellation between pages. Packaging is separate. Native compilation and visual/DPI proof remain pending.

## Native PDF output

On macOS, PDFOutputWriter uses PDFKit to copy selected pages and optionally apply the existing screen/JPEG options. Original all-page mode returns the original input. Rewritten selections normalize in ascending original order, check text/geometry/rotation, and have a 200-page limit. Links, outlines, tags, metadata and conformance are not certified; callers must disclose that limitation. Native test gate remains open.

## EX02C/E/F follow-up

GeneratedArchiveInventory inspects actual produced stored ZIP (directory/local headers, contiguous entries, sizes, CRC-32), binary WebArchive plist, generated MIME boundaries/base64, and WARC record lengths/IDs. Bounded, read-only, no arbitrary archive extraction, schema validation or browser replay. ZIP support intentionally matches existing writers (no compression/encryption/ZIP64/comments/extra fields). Text output helper offers LF/CRLF and an explicitly generated LaTeX article envelope; it never executes TeX. Native macOS QuartzPDFOutput enumerates only regular system .qfilter files in /System/Library/Filters, applies the public context API, redraws only matching zero-origin unrotated page geometries, verifies text/boxes/page count, does not certify filter effects, tags, links, outlines or conformance. The actual native API and filter results must be tested on macOS. Independent PDF/A and PDF/X validation is not implemented in this library.

Executed Linux Swift 6.2.1: exact portable sources GeneratedArchiveInventory.swift 9bf1d8a74054056a04d4204d0f9ad86c54d2d450, ExportTextOutput.swift 3d6b2e6abfe1ac435ca8a9b06ba1625322b6a24c and ArchiveAndTextTests.swift aa3134d9e8576e8c9188e194f89db1ac362b9de7 plus existing support sources/tests; 7/7 Swift Testing methods passed (0.008s). Native Quartz tests authored, not executed.
