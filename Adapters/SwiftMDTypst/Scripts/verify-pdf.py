#!/usr/bin/env python3
import json
from pathlib import Path
from pypdf import PdfReader

output=Path(__file__).resolve().parents[1]/"Proof"/"Results"
headings=json.loads((output/"headings.json").read_text(encoding="utf-8"))
assert [h["key"] for h in headings]==["vm-0","vm-1","vm-2"],headings
assert [h["title"] for h in headings]==["Methods and Results","Methods","Methods"],headings
source=(output/"document.typ").read_text(encoding="utf-8")
assert all("<"+h["key"]+">" in source for h in headings)
assert source.count('#text("[x] ")') == 2
assert source.count('#text("[ ] ")') == 3
assert "#raw(" in source  # only the explicitly authored Swift fence
reader=PdfReader(str(output/"document.pdf"))
assert len(reader.pages)>=1
text="\n".join(page.extract_text() or "" for page in reader.pages)
for word in ["Methods and Results","Collect data","Record values","Alpha","42","Beta","Quoted note","let sample","Completed proof task","Nested pending proof task","Open proof task","Ordered proof task","Ordered pending task"]:
    assert word in text,(word,text)
assert text.count("[x]") >= 2, text
assert text.count("[ ]") >= 3, text
bookmarks=[]
def visit(tree):
    for entry in tree:
        if isinstance(entry,list):
            visit(entry)
        else:
            bookmarks.append((entry.title,reader.get_destination_page_number(entry)))
visit(reader.outline)
assert len(bookmarks)>=3,bookmarks
assert [h[0] for h in bookmarks][:3]==["Methods and Results","Methods","Methods"],bookmarks
assert all(0<=p<len(reader.pages) for _,p in bookmarks),bookmarks
receipt={
    "typst":"0.15.1",
    "pages":len(reader.pages),
    "generated_headings":headings,
    "pdf_outline_destinations":[{"title":title,"pageIndex":page} for title,page in bookmarks],
    "semantic_checks":"passed",
    "source_recovery":"all text and generated PDF bookmarks checked",
    "limits":"This checks only the pinned nonmath fixture; arbitrary GFM/full markdown and source-mapped PDF anchor coordinates are not yet certified."
}
(output/"verification.json").write_text(json.dumps(receipt,indent=2)+"\n",encoding="utf-8")
print("SWIFTMDTYPST PDF PASS pages",len(reader.pages),"heading/bookmarks",len(bookmarks))
