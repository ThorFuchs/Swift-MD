# Pinned cmark-gfm test fixtures

The `.txt` files are unmodified copies from `test/` in
https://github.com/github/cmark-gfm/tree/27d942c8b0a62d192f616e5bf3578f4b6a89e180/test.
They are included as SwiftPM test resources so `swift test` works offline and
without a Ruby, Python, or external cmark runtime. They do not ship in the
SwiftMD library target.

| File | SHA-256 |
| --- | --- |
| `spec.txt` | `7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c` |
| `extensions.txt` | `a2a45e98be9fca95f564f927265a0f63beea6cae5369d1cf4bde44caa51b2a3a` |
| `regression.txt` | `0920d7e8134d5e4ec3693f3f52d904b42de45e23a66c29f54fe714dc54213fd9` |
| `smart_punct.txt` | `b1dcfb0e0b6f314cf087edc06f47d9271849da539acfbfac0b9d7b16f10139c9` |
| `extensions-full-info-string.txt` | `dec5fc65880d74f97d5181e0b75466fbe12662cda8383d8b51fd78e06191092f` |
| `extensions-table-prefer-style-attributes.txt` | `3d902a4a1ce48df5dd7910647602fbae4535d8bac6700e918280fe1d928a4cee` |

The spec and extension fixtures identify the CommonMark Spec and CC BY-SA 4.0;
see the adjacent [LICENSE](LICENSE). Upstream's full source
license notices are in `Vendor/GitHubCMark/COPYING`. The CR characters in the
regression fixture and the NUL in the full-info fixture are intentional; do not
normalize fixture bytes.

