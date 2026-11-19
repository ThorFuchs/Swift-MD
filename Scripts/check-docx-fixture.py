#!/usr/bin/env python3
"""Independently validate the generated SwiftMDDOCX example package."""
import posixpath
import sys
import xml.etree.ElementTree as ET
import zipfile

path = sys.argv[1]
expected = {"[Content_Types].xml", "_rels/.rels", "word/document.xml",
            "word/_rels/document.xml.rels", "word/styles.xml", "word/numbering.xml"}
with zipfile.ZipFile(path) as archive:
    assert archive.testzip() is None, "bad ZIP CRC"
    assert set(archive.namelist()) == expected, "unexpected OPC parts"
    for name in expected:
        ET.fromstring(archive.read(name))
    namespace = {"r": "http://schemas.openxmlformats.org/package/2006/relationships"}
    for name, base in (("_rels/.rels", ""), ("word/_rels/document.xml.rels", "word")):
        for rel in ET.fromstring(archive.read(name)).findall("r:Relationship", namespace):
            assert rel.get("TargetMode") != "External", "unexpected external relationship"
            target = posixpath.normpath(posixpath.join(base, rel.attrib["Target"]))
            assert target in expected, f"missing relationship target: {target}"
print("ZIP CRC, six XML parts and internal relationship targets passed")
