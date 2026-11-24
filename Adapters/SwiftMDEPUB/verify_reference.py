"""Independent checks of actual Swift-produced SwiftMDEPUB reference artifacts."""
from pathlib import Path
from zipfile import ZipFile
import hashlib
import json
import posixpath
import struct
import sys
import xml.etree.ElementTree as ET

root = Path(sys.argv[1])
original = (Path(__file__).parent / "Tests/SwiftMDEPUBTests/Fixtures/Reference.md").read_bytes()
X = "{http://www.w3.org/1999/xhtml}"
P = "{http://www.idpf.org/2007/opf}"

def check(file, source):
    with ZipFile(file) as z:
        assert z.testzip() is None
        names = z.namelist()
        assert len(names) == len(set(names))
        assert names[0] == "mimetype" and z.read("mimetype") == b"application/epub+zip"
        first = z.infolist()[0]
        assert first.compress_type == 0 and first.header_offset == 0 and not first.extra
        header = file.read_bytes()[:30]
        assert struct.unpack_from("<H", header, 28)[0] == 0
        ET.fromstring(z.read("META-INF/container.xml"))
        opf = ET.fromstring(z.read("EPUB/package.opf"))
        manifest = {i.attrib["id"]: i.attrib["href"] for i in opf.findall(f"{P}manifest/{P}item")}
        spine = opf.findall(f"{P}spine/{P}itemref")
        assert len(spine) == 1
        chapter = "EPUB/" + manifest[spine[0].attrib["idref"]]
        html = ET.fromstring(z.read(chapter))
        nav = ET.fromstring(z.read("EPUB/nav.xhtml"))
        assert html.tag == X + "html"
        headings = [e for e in html.iter() if e.tag in {X + "h1", X + "h2"}]
        assert [e.attrib["id"] for e in headings] == ["vm-0", "vm-1", "vm-2", "vm-3"]
        targets = [a.attrib["href"] for a in nav.iter(X + "a")]
        assert targets == [chapter.removeprefix("EPUB/") + "#" + e.attrib["id"] for e in headings]
        text = " ".join(html.itertext())
        for value in ("The living publication", "Nested ideas stay visible.", "Compile the publication.",
                      "Evidence and observations", "struct Publication", "5 < 7 & 9 > 3"):
            assert value in text, value
        assert len(list(html.iter(X + "table"))) == 1
        assert len(list(html.iter(X + "ul"))) == 2
        assert len(list(html.iter(X + "ol"))) == 1
        images = list(html.iter(X + "img"))
        assert len(images) == 3 and images[0].attrib["src"] == images[2].attrib["src"]
        paths = {"EPUB/" + path for path in manifest.values()}
        for element in images + list(html.iter(X + "link")):
            ref = element.attrib.get("src", element.attrib.get("href"))
            path = posixpath.normpath(posixpath.join(posixpath.dirname(chapter), ref))
            assert path in names and path in paths
            if element.tag == X + "img":
                payload = z.read(path)
                assert payload.startswith(b"\x89PNG\r\n\x1a\n")
                assert struct.unpack_from(">II", payload, 16) == (320, 112)
        assert all(path in names for path in paths)
        assert not list(html.iter(X + "script"))
        source_paths = [p for p in names if p.startswith("EPUB/source/")]
        if source:
            md = [p for p in source_paths if p.endswith(".md")]
            assert len(md) == 1 and z.read(md[0]) == original
            record = json.loads(z.read("EPUB/source/publication.json"))
            assert len(record["navigation"]) == 4
            for res in record["resources"]:
                role = res["role"]
                folder, ext = {"markdown": ("source", "md"), "xhtml": ("content", "xhtml"),
                               "css": ("styles", "css"), "png": ("media", "png")}[role]
                payload = z.read(f"EPUB/{folder}/{res['id'].lower()}.{ext}")
                assert len(payload) == res["byteCount"]
                assert hashlib.sha256(payload).hexdigest() == res["sha256"]
        else:
            assert not source_paths
        print(f"{file.name}: CRC, XML, navigation, visible content, resource closure and source policy OK")

check(root / "reference-reading.epub", False)
check(root / "reference-source.epub", True)
