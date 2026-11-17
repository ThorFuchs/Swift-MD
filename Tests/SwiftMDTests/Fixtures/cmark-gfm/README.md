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

`spec.txt` is the GitHub Flavored Markdown Spec, based on the CommonMark Spec
by John MacFarlane; its metadata identifies CC BY-SA 4.0. `extensions.txt`,
`extensions-full-info-string.txt`, and `extensions-table-prefer-style-attributes.txt`
identify their respective authors as Yuki Izumi, Ashe Connor, and FUJI Goro,
and each declares CC BY-SA 4.0. These files are included unmodified. The full
license is in the adjacent [LICENSE](LICENSE); the canonical license URL is
https://creativecommons.org/licenses/by-sa/4.0/.

`regression.txt` and `smart_punct.txt` have no individual license header; retain
the upstream COPYING notice and assess their provenance for the distribution
being prepared. Upstream's full source
license notices are copied to `ThirdPartyLicenses/cmark-gfm-COPYING.txt` at the
SwiftMD repository root. The CR characters in the
regression fixture and the NUL in the full-info fixture are intentional; do not
normalize fixture bytes.

