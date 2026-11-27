#!/usr/bin/env python3
"""Independent format/byte proof of the Foundation writer, not browser replay.
Run: python3 Scripts/prove-web-page-export.py (requires Swift 6 and Python 3).
Compiles the actual source in an isolated temporary directory; no network.
"""
import base64
import email.policy
import hashlib
import plistlib
import subprocess
import tempfile
from email.parser import BytesParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WRITER = ROOT / 'Sources/SwiftMDExport/WebPageExport.swift'
PNG = base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAIAAAACCAIAAAD91JpzAAAAFklEQVR4nGOUq5jGwMDAxMDAwMDAAAANwgEwIh/K7gAAAABJRU5ErkJggg==')
JPEG = base64.b64decode('/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAACAAIDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDAooor2z5U/9k=')
SWIFT = r'''
import Foundation
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let png = try Data(contentsOf: root.appendingPathComponent("fixture.png"))
let jpg = try Data(contentsOf: root.appendingPathComponent("fixture.jpg"))
let rasters = [WebPageExport.Raster(index: 1, isPNG: true, bytes: png),
               WebPageExport.Raster(index: 2, isPNG: false, bytes: jpg)]
func html(_ urls: [String]) -> Data {
    Data(("<!doctype html><html><head><meta charset=\"utf-8\"><style>body{color:black}</style></head><body><p>Grüße 🦊</p>" + urls.map { "<img src=\"\($0)\">" }.joined() + "</body></html>").utf8)
}
let inline = html(rasters.map(\.dataURL))
let archive = html(rasters.map(\.location))
let page = try WebPageExport(standaloneHTML: inline, archiveHTML: archive, rasters: rasters, unresolvedMediaCount: 0, hasInertLinks: false)
for (format, name): (WebPageExportEncoding, String) in [(.html, "page.html"), (.webArchive, "page.webarchive"), (.mhtml, "page.mhtml"), (.warc, "page.warc")] {
    try page.encode(format).write(to: root.appendingPathComponent(name))
}
try archive.write(to: root.appendingPathComponent("expected.html"))
let external = try WebPageExport(externalHTML: Data("<html>Grüße</html>".utf8))
try external.encode(.mhtml).write(to: root.appendingPathComponent("external.mhtml"))
do { _ = try WebPageExport(externalHTML: Data([255])); fatalError("accepted invalid UTF8") }
catch WebPageExportError.invalidHTML {}
do { _ = try WebPageExport(standaloneHTML: inline, archiveHTML: archive, rasters: Array(repeating: rasters[0], count: 129), unresolvedMediaCount: 0, hasInertLinks: false); fatalError("accepted too many assets") }
catch WebPageExportError.budget {}
'''

def verify(root):
    html = (root / 'page.html').read_bytes()
    expected = (root / 'expected.html').read_bytes()
    urls = ['https://viewmarkdown.invalid/index.html', 'https://viewmarkdown.invalid/assets/1.png', 'https://viewmarkdown.invalid/assets/2.jpg']
    bodies = [expected, PNG, JPEG]
    assert 'Grüße 🦊'.encode() in html and b'<style>' in html
    for mime, image in [('image/png', PNG), ('image/jpeg', JPEG)]:
        assert (f'data:{mime};base64,'.encode() + base64.b64encode(image)) in html
    assert b'viewmarkdown.invalid' not in html
    print('HTML: embedded CSS, Unicode and both exact data URLs PASS')

    archive = plistlib.loads((root / 'page.webarchive').read_bytes())
    resources = [archive['WebMainResource']] + archive['WebSubresources']
    assert not archive['WebSubframeArchives']
    assert [r['WebResourceURL'] for r in resources] == urls
    assert [r['WebResourceData'] for r in resources] == bodies
    assert [r['WebResourceMIMEType'] for r in resources] == ['text/html', 'image/png', 'image/jpeg']
    print('WebArchive: plist root and two exact subresources PASS')

    raw = (root / 'page.mhtml').read_bytes()
    message = BytesParser(policy=email.policy.default).parsebytes(raw)
    assert message.get_content_type() == 'multipart/related' and not message.defects
    assert message.get_param('type') == 'text/html'
    parts = list(message.iter_parts())
    assert [p['Content-Location'] for p in parts] == urls
    assert [p.get_payload(decode=True) for p in parts] == bodies
    assert all(not p.defects for p in parts)
    assert [p.get_content_type() for p in parts] == ['text/html', 'image/png', 'image/jpeg']
    assert all(len(line) <= 76 for p in parts for line in p.get_payload().splitlines())
    external = BytesParser(policy=email.policy.default).parsebytes((root / 'external.mhtml').read_bytes())
    assert [p.get_payload(decode=True) for p in external.iter_parts()] == ['<html>Grüße</html>'.encode()]
    print('MHTML: independent MIME parser, locations, base64 and exact payloads PASS')

    raw = (root / 'page.warc').read_bytes()
    records = []
    cursor = 0
    while cursor < len(raw):
        head, sep, _ = raw[cursor:].partition(b'\r\n\r\n')
        assert sep
        lines = head.decode('ascii').split('\r\n')
        assert lines.pop(0) == 'WARC/1.1'
        fields = dict(line.split(': ', 1) for line in lines)
        start = cursor + len(head) + 4
        end = start + int(fields['Content-Length'])
        assert raw[end:end+4] == b'\r\n\r\n'
        records.append((fields, raw[start:end]))
        cursor = end + 4
    assert cursor == len(raw)
    assert [f['WARC-Type'] for f, _ in records] == ['warcinfo', 'resource', 'resource', 'resource']
    assert [f['WARC-Target-URI'] for f, _ in records[1:]] == urls
    assert [body for _, body in records[1:]] == bodies
    assert len({f['WARC-Record-ID'] for f, _ in records}) == 4
    assert all(f['WARC-Warcinfo-ID'] == records[0][0]['WARC-Record-ID'] for f, _ in records[1:])
    assert b'not a network crawl' in records[0][1]
    print('WARC: independent record traversal, lengths, IDs and exact payloads PASS')


def main():
    with tempfile.TemporaryDirectory(prefix='vm-web-proof-') as tmp:
        root = Path(tmp)
        (root / 'main.swift').write_text(SWIFT, encoding='utf-8')
        (root / 'fixture.png').write_bytes(PNG)
        (root / 'fixture.jpg').write_bytes(JPEG)
        executable = root / 'proof'
        subprocess.run(['swiftc', '-swift-version', '6', str(WRITER), str(root / 'main.swift'), '-o', str(executable)], check=True)
        subprocess.run([str(executable), str(root)], check=True)
        verify(root)
        print('Writer SHA256:', hashlib.sha256(WRITER.read_bytes()).hexdigest())
        print('4/4 container format checks; invalid UTF-8 and resource limit rejected. No native browser replay claimed.')


if __name__ == '__main__':
    main()
