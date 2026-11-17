# Published GFM 0.29 comparison

This is an investigation of the 26 exact-HTML differences reported for the
[separately preserved published specification](../Tests/PublishedGFM/README.md),
not a full conformance certification. The snapshot has 677 numbered examples;
its SHA-256 and CC BY-SA 4.0 attribution are recorded alongside it. The
published HTML explicitly uses `→` to display tabs; extraction replaces that
marker with a tab and decodes the example text. The published 2019 document
and the cmark-gfm fixtures bundled with SwiftGFM are different corpora.

SwiftMD Core at `a1cdc503e6a381af77bd5b9fe611c6ca6bd30d50` used SwiftGFM
1.0.0, backed by cmark-gfm commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180`.
For the baseline comparison, `allowUnsafeHTML` and all five GFM extensions
(table, strikethrough, autolink, tagfilter and tasklist) were enabled. This
is a comparison configuration, **not a sanitization recommendation**. A
separately built upstream C executable and SwiftMD emitted identical bytes
for all **677/677** inputs with that same configuration. The earlier 747/747
comparison used the separate cmark-gfm fixture corpus.

| Cases | Count | Finding and practical consequence |
| --- | ---: | --- |
| 140, 141, 142, 145, 147 | 5 | The globally enabled tagfilter escapes `script`/`style` tags, while these published expectations show raw tags. Disabling tagfilter makes these five byte-identical, but makes case 657 differ. |
| 279, 280 | 2 | Checkbox attribute order and void-element serialization differ. A Chrome 157 DOM comparison for these two inputs found the same elements, attributes and text. This is limited to those examples, not a general HTML-equivalence guarantee. |
| 324 | 1 | The published expectation preserves the eight-digit numeric reference as escaped text; the pinned backend emits U+FFFD. The specification permits 1–7 decimal or 1–6 hexadecimal digits, whereas the pinned C decoder accepts up to eight of either (`src/houdini_html_u.c`, lines 74–79). Additional boundary probes confirm that seven- and eight-digit hexadecimal references can decode where the published specification would leave them literal. This is observable text behavior. |
| 398, 426, 434, 435, 436, 473, 474, 475, 477 | 9 | The published output has nested `strong` elements; cmark-gfm's HTML renderer deliberately omits a `strong` element directly inside another `strong` (`src/html.c`, lines 366–373). This changes DOM structure and can affect CSS or accessibility; visual or semantic equivalence is not presumed. |
| 611, 615, 617, 620, 621 | 5 | These examples precede the specification's autolink extension section. The globally enabled extension adds links. Disabling it makes these five byte-identical but causes extension examples 622–633 to differ. |
| 634, 635 | 2 | XMPP autolink recognition and link boundaries differ even in the extension section. Link targets or which text is linked can change. |
| 649, 650 | 2 | Malformed HTML-comment recognition differs when unsafe HTML is allowed. In Chrome 157, 649 produces a comment node instead of the expected visible text; in the first paragraph of 650, `<!-->` becomes an empty comment node instead of visible text. Raw HTML is a separate trust boundary and is not sanitized. |

The four global configurations produce the following exact byte matches. All
use `allowUnsafeHTML`; the listed variation changes only those extensions:

| Extensions | Exact matches | Differing |
| --- | ---: | ---: |
| All five | 651 | 26 |
| Without tagfilter | 655 | 22 |
| Without autolink | 644 | 33 |
| Without either | 648 | 29 |

The base examples and extension examples have different contexts. No single
one of these global switches makes the entire published page byte-identical;
turning off tagfilter globally would also change a security-relevant option.
Counts describe exact bytes, not the number of semantic or security failures.

## Decision and ownership

Keep the existing byte-for-byte SwiftGFM/backend contract and do not silently
rewrite the baseline output, change parser extensions globally, or describe
raw HTML as safe. SwiftMD owns documenting its profile, making any future CLI
configuration explicit, and maintaining comparison and browser diagnostics.
SwiftGFM owns its documented wrapper and backend version; a compatibility or
backend update, especially for XMPP, entities and malformed comments, requires
separate investigation and an explicit decision with that project. No change to
SwiftGFM or vendored cmark-gfm is implied by this analysis. A spec-compatible
alternative profile would need a precise contract, per-case option policy,
security review and new tests before adoption. Fixture provenance and release
licensing remain separate release-review tasks.

The joint parser investigation, proposed opt-in contract and targeted acceptance
gate are recorded in [GFM029_PROFILE.md](GFM029_PROFILE.md). No selectable
profile or qualified alternative parser exists yet.

Reproduce from the repository root after building the CLI and a **separate**
upstream C renderer at the pinned commit:

```sh
python3 Scripts/test-published-gfm.py  # exits 1 while byte differences exist
python3 Scripts/analyze-published-gfm.py --reference /absolute/path/to/cmark-gfm
node Scripts/test-browser.mjs           # Chromium; checks DOM cases and no page JS
```

The analysis script checks the snapshot checksum, all 677 example IDs, the
exact mismatch identities for all four configurations, SwiftMD/C parity, and
five additional numeric-reference boundary probes.
It exits nonzero if any of those audited baselines change. It reports known
byte differences; exit zero does not mean all published examples matched.
Reference executable provenance must be verified by the caller, not inferred
from its version string. The Chrome DOM check runs against a detached `div`;
its result is targeted evidence for four examples, not a cross-browser audit.
