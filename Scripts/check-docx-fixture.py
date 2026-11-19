#!/usr/bin/env python3
"""Independently validate the generated SwiftMDDOCX example package."""
import posixpath
import sys
import xml.etree.ElementTree as ET
import zipfile

path = sys.argv[1]
expected = {"[Content_Types].xml", "_rels/.rels", "word/document.xml",
            "word/_rels/document.xml.rels", "word/styles.xml", "word/numbering.xml", "word/settings.xml"}
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
    word = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    settings = ET.fromstring(archive.read("word/settings.xml"))
    setting = settings.find(f"{{{word}}}compat/{{{word}}}compatSetting")
    assert setting is not None
    assert setting.attrib == {f"{{{word}}}name": "compatibilityMode", f"{{{word}}}uri": "http://schemas.microsoft.com/office/word", f"{{{word}}}val": "15"}
    types = {"c": "http://schemas.openxmlformats.org/package/2006/content-types"}
    overrides = ET.fromstring(archive.read("[Content_Types].xml")).findall("c:Override", types)
    assert any(o.get("PartName") == "/word/settings.xml" and o.get("ContentType") == "application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml" for o in overrides)
    rels = ET.fromstring(archive.read("word/_rels/document.xml.rels")).findall("r:Relationship", namespace)
    assert any(r.get("Type") == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings" and r.get("Target") == "settings.xml" for r in rels)
print("ZIP CRC, seven XML parts, relationships and Word compatibility setting passed")
