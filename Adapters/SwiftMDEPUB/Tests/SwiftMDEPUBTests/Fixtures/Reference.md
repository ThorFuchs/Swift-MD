# The living publication

A real Markdown document, compiled from **original source** into a portable digital publication. Reading should feel natural, calm, and clear — even offline.

This paragraph includes *emphasis*, **strong text**, ~~a correction~~, inline `let value = 42`, and the characters 5 < 7 & 9 > 3.

Jump to [the evidence table](#vm-2) or visit the [W3C EPUB specification](https://www.w3.org/TR/epub-33/).

## Reading, structure, and rhythm

- One original source
  - Nested ideas stay visible.
  - Resources belong to the publication.
- A portable reading experience
- A clear separation of content and design

3. Read the original.
4. Compile the publication.
5. Share the result.

> A document is more than a file: it is a composition of content, design, and resources.

---

## Evidence and observations

| Component | Status | Count |
| :--- | :---: | ---: |
| Headings | Ready | 4 |
| Resources | Captured | 2 |
| Source | Preserved | 1 |

The two illustrations below are generated test patterns, not external images.

![Petrol sample](images/petrol.png "A test pattern")

![Ochre sample](images/ochre.png "Another test pattern")

The first resource can be referenced again: ![Repeated petrol sample](images/petrol.png).

## A small Swift example

```swift
struct Publication {
    let title: String
    let revision: Int
}

let book = Publication(title: "Glass & Paper", revision: 1)
print(book.title)
```

Return to [the beginning](#vm-0). The original Markdown remains part of the explicit source-inclusive edition.
