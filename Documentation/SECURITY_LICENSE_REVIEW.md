# SVG, process and source-distribution review

Review scope: SwiftMD source and its pinned dependencies on 17 November 2026.
This is a reproducible engineering review, not an independent penetration
test, a general sanitizer certification, or legal advice. Changes in dependencies,
distribution contents, host policy or browser engines require re-evaluation.

## SVG boundary

`PeleNodeRenderer` disables Pele links and images. Its output is limited to
2,000,000 UTF-8 bytes before XML parsing, then `ValidatedSVG` requires one SVG
root, the SVG namespace, the requested ID and a positive `viewBox`. It rejects
DTDs, processing instructions, unknown elements and attributes, scripts,
external/local resource references, event attributes, CSS escapes, comments
and unknown CSS functions. IDs are restricted to the root and direct-child
accessibility title/description; ARIA references must match. Validated bytes
are inserted after HTML serialization, so attributes such as `viewBox` retain
their original spelling. Invalid output produces a diagnostic and preserves
the escaped original block.

The root's first literal `</svg>` must terminate the entire fragment. This
additional check is necessary because FoundationXML on the tested Linux build
accepted a first XML root while ignoring trailing bytes. Nested SVG, comments,
CDATA and processing instructions are separately rejected. This strict profile
therefore also rejects trailing whitespace and self-closing SVG roots.

The validator has an intentionally narrow allowlist, not a general SVG
sanitizer. It permits selected `var(...)` values required by Pele. CSS custom
properties and classes can depend on **host CSS**, which may alter rendering
or introduce resource references; do not treat this validator as isolating an
SVG from untrusted host styles. Raw HTML and arbitrary renderer/plugin HTML are
separate trust boundaries. The host must supply distinct page-level SVG prefixes.
The tests exercise malicious tags, events, local/external references, namespace
changes, encodings, CSS escapes, DTDs, accessibility ID collisions and actual
Pele examples. They do not prove absence of all browser-parser differences,
resource exhaustion or vulnerabilities in arbitrary renderers.

## Process and resource boundary

Node executable/module paths, module code and the inherited environment are
trusted configuration. For example, Node interprets `NODE_OPTIONS` before the
supplied program and can preload code; see the [Node CLI documentation](https://nodejs.org/api/cli.html#node_optionsoptions).
JSON is used for Markdown-derived inputs, not JavaScript interpolation.
Temporary files are held in a private directory. KaTeX and Pele each reject
inputs above 16,384 UTF-8 bytes. Renderer stdout is size-checked after Node exits,
and the Swift read itself is capped at 2,000,001 bytes to detect an over-limit
file even if it grew after the metadata check. Renderer stderr retained in a
failure diagnostic is capped at 4,096 bytes.

Neither Node adapter kills a timed-out process, limits aggregate memory or disk,
or prevents writes while the process runs. A child inheriting stdout can remain
alive after its parent exits and keep writing; a bounded read is not a live
output limit. `Scripts/run-linux-constrained.sh` is an opt-in outer worker:
its process-group deadline and per-process address-space/file-size limits are
not a sandbox. Descendants that create another session can escape the deadline;
per-process limits do not bound aggregate use. An executable test demonstrates
that known escape, rather than treating it as a security guarantee. Stronger
isolation needs a separately configured and tested OS sandbox/cgroup policy.
SwiftGFM's parser has its own resource boundaries; a Swift task cancellation
does not stop synchronous foreign code.

An additional [Linux supervised worker](PROCESS_ISOLATION.md) bounds live
stdin/stdout/stderr and retains stdout until successful completion. It also
enforces a deadline and per-process resource limits. It still does not contain
detached descendants, impose aggregate quotas, or isolate the filesystem,
network or credentials.

An experimental separate systemd/cgroup-v2 profile and its fail-closed runtime
guard are described in [process isolation](PROCESS_ISOLATION.md). They require
system-manager privileges, a trusted root-owned installation and target-specific
validation; they are not silently enabled by either adapter.

## License and fixture evidence

`Scripts/audit-dependencies.py` compares the retained license/notice bytes with
the revisions in the SwiftPM lockfile. The original SwiftGFM `NOTICE`, which
was missing from SwiftMD's inventory, is now retained unchanged. Its upstream
paths are mapped in [the notice inventory](../ThirdPartyLicenses/README.md).

The four retained cmark-gfm fixture SHA-256 values match the separately checked-out
upstream commit `27d942c8b0a62d192f616e5bf3578f4b6a89e180`; the published GFM
HTML snapshot matches its recorded SHA-256. The spec and individually marked
extension files retain their authors and CC BY-SA 4.0 notice in the fixture
[README](../Tests/SwiftMDTests/Fixtures/cmark-gfm/README.md). The formerly
bundled `regression.txt` and `smart_punct.txt` have no individual
license header. For example, the latter contains the name “Shelob” in both input
and expected output. That observation is not a conclusion about rights or
infringement; assess whether the material may be distributed in the relevant
jurisdictions and distribution format. This targeted text search is not an
exhaustive review of every fixture or Git-history version. The
[CC BY-SA legal code](https://creativecommons.org/licenses/by-sa/4.0/legalcode.en)
specifies attribution and applicable share-alike conditions; do not infer that
a checksum alone establishes rights in all source material.

The Swift-GFM session independently traced both unchanged files in the pinned
upstream history. `smart_punct.txt` was introduced by John MacFarlane in
[commit 515e823](https://github.com/commonmark/cmark/commit/515e823051533a91cae322536e6926eea4c48113),
including the example mentioned above. `regression.txt` was introduced by Nick
Wellnhofer in [commit 848ca96](https://github.com/commonmark/cmark/commit/848ca96890db32eb98d44765886853bed626a4ee)
and later received changes from multiple contributors. The pinned upstream
[COPYING](https://github.com/github/cmark-gfm/blob/27d942c8b0a62d192f616e5bf3578f4b6a89e180/COPYING)
identifies `test/spec.txt` and test software separately, without naming these
two text files. Git attribution documents contribution history, not the rights
chain of every example or a legal conclusion for a distribution.

The same short `smart_punct.txt` example appears in the 2006 Pandoc initial
import, before the cmark commit, in
[tests/writer.markdown](https://github.com/jgm/pandoc/blob/df7b68225101966051f8b592a27127bf789eb81e/tests/writer.markdown).
That file describes some tests as adaptations but does not identify the origin
of this particular example. Its presence is evidence of an earlier occurrence,
not proof of a transfer route, licensing terms, or a complete rights chain.
At the user's direction the two files were removed from the current SwiftMD
source snapshot; the four remaining fixtures are unmodified. This removed 42
upstream expectation cases. Thirteen separately authored neutral cases cover
selected behaviors, not the full removed corpus. The removal does not erase
earlier SwiftMD history or remove the files from the existing SwiftGFM 1.0.0
source tag. Fetching fixtures separately changes distribution, not the rights
question for the fetch and use. Review the full distribution, including
transitive source dependencies and history, before any release.

SwiftGFM 1.0.1 removes both files from its new source snapshot; its 1.0.0 tag
and prior Git history remain unchanged. This does not resolve their rights.

On 19 November 2026, an additional independent blob comparison checked the
17 Swift-Highlight 1.0.1 inputs previously described as similar or extended
relative to the pinned highlight.js revision. All 17 match their corresponding
HighlightKit `524c185b0553756498c1b6a1765e8d119c4623a6` files byte for byte,
and those files also match the HighlightKit initial import.
Fifteen also match highlight.js files at other identified commits byte for
byte. The two XML inputs match the pinned highlight.js files after removal of
their UTF-8 byte order marks, with no other byte difference. The script below
records each exact source commit and verifies that their commit timestamps
precede HighlightKit's initial import; timestamps do not prove a transfer path.
HighlightKit's MIT license and the same highlight.js BSD-3-Clause license at all
12 referenced highlight.js revisions match the retained notice bytes. This
narrowly resolves the prior unexplained byte differences; it is not proof of
ownership of every contribution or a legal opinion on any distribution.

```sh
python3 Scripts/audit-highlight-fixtures.py \
  --highlightkit-source /absolute/path/to/HighlightKit \
  --highlightjs-source /absolute/path/to/highlight.js
```

The public Swift-Highlight repository's fixture inventory describes the
earlier comparison against one pinned highlight.js commit. SwiftMD's new
comparison is recorded here; it does not modify the sister repository or its
history. SwiftPM independently fetches Swift-Highlight's source, while the
generated SwiftMD adapter mirror does not copy those fixtures into itself.

An independent source scan on 19 November also identified a separately fetched
SwiftSoup 2.11.3 source-distribution issue: its performance-test corpus contains
six saved third-party web pages. The Google page includes an explicit dual
MIT/GPL notice for Math.uuid.js and another third-party code notice. The
generated mirror does not copy these files, but SwiftPM fetches the upstream
SwiftSoup source package. The [SwiftSoup source audit](../ThirdPartyLicenses/SwiftSoup-SOURCE-AUDIT.md)
records the precise path, checksum and scope. The presence of a notice is not
evidence of infringement; it does mean SwiftSoup's root MIT license alone is
not a complete inventory of the fetched source snapshot. Review this corpus
or select and verify an alternative distribution before treating the source
dependency review as complete.
The [external review packet](EXTERNAL_RIGHTS_REVIEW.md) lists the intended
distribution paths, exact evidence and questions for a qualified reviewer.

The bundled KaTeX 0.19.1 `dist/katex.js` contains attribution for utility
functions adapted from Facebook's React under Apache-2.0 and for SVG data
adapted from font glyphs under SIL OFL 1.1. The mirror now includes the
identified copyright notices and license texts alongside the SwiftPM resources;
see `ThirdPartyLicenses/KaTeX-THIRD-PARTY.md`. The source text and license
markers are verified, but their inclusion is not a complete legal clearance.

For Pele 1.13.0, the public tag resolves to
`3a2f075ee0c3d914f0fad3545fc0f193693975ac`. Its npm package declares no runtime
dependencies, and the pinned source uses relative module imports; the build
bundles `src/index.ts` and configures esbuild to omit legal comments. Both
bundled JavaScript files were reproduced byte-for-byte from that commit with
the lockfile-pinned esbuild 0.28.2. Metafiles report no `node_modules` inputs;
the IIFE includes esbuild's synthetic runtime helpers. The esbuild MIT license
and Pele's MIT/ISC license are included beside the bundled files; see
`ThirdPartyLicenses/Pele-THIRD-PARTY.md`. These observations do not establish
the origin and licensing of every source fragment. Further third-party review
remains necessary before publishing the bundled mirror.

On 18 November, a search of Pele's pinned `src/` found that its common journey
and timeline lexer explicitly describes rules ported from Mermaid. The exact
Mermaid source revision is unspecified. As a precaution the mirror generator
now includes Mermaid's MIT license and copyright notice with the renderer
resources; its source and checksum are recorded in the Pele notice. The
additional attribution does not establish the complete provenance of the port.
At the separately identified Mermaid reference commit, the journey and timeline
grammar headers also declare MIT and name Knut Sveidqvist with copyright years
2015 and 2023. Those file-level notices are now included alongside the bundled
resources; the Pele source does not identify an exact Mermaid revision.

Pele's Gantt axis source also describes behavior following d3-time,
d3-time-format and d3's time scale. No d3 `node_modules` inputs occur in the
recorded esbuild metafiles; this does not settle whether code is derivative.
As a precaution, the relevant ISC notices from identified public d3 reference
tags are included with the renderer. Their upstream commits and checksums are
documented in `ThirdPartyLicenses/Pele-THIRD-PARTY.md`; the source does not
identify an exact d3 revision.

On 19 November 2026, ScanCode Toolkit 33.0.0rc1 scanned a locally generated
adapter candidate from source commit `b95d3fce967e51f1b0fff93b42dee8c5d16d5dd4`:
58 files were scanned with no scanner errors. It reported an MS-RL reference
in minified `pele.global.js`. Its matched text is `ms:Rl}};`, a JavaScript
property and minified identifier, not the text `MS-RL` or a license notice.
The corresponding unminified code is in Pele's `src/diagrams/gantt/axis.ts`.
This determination addresses that specific scanner match only. A second scan
of the mirror generated from `55cb84e54cadfe0ff10958563e30842250d30965` after
the d3 notice additions covered 62 files without scanner errors. In the
third-party inventory README it also inferred CC BY-SA 3.0 and an unknown
license from generic CC BY-SA and `cmark-gfm-COPYING.txt` references; those
lines contain no version 3.0 declaration, and the retained cmark notice is the
source for the actual fixture terms. These are triage observations about the
scanner's matches, not a change to any underlying license.

The same ScanCode setup separately scanned the `71d23c5` Swift-Highlight
1.0.1 source snapshot (986 files) with no scanner errors. Detected license
expressions were combinations of Apache-2.0, MIT and BSD-3-Clause. This scan
does not include Git history. A separate scan of the SwiftMD `55cb84e` source
archive covered 123 files with no scanner errors; its MS-RL, CC BY-SA 3.0 and
unknown-license-reference matches occur in this review's discussion, generic
notice references or the generator's literal `LICENSE` paths. They do not
identify an additional bundled implementation under those terms. These are
specific match triage findings, not determinations about all source content.
SwiftGFM 1.0.1's `2cb9450` source archive, including its vendored cmark-gfm
snapshot, was scanned separately: 185 files, no scanner errors, with Apache-2.0,
CC BY-SA 4.0, MIT and BSD-2-Clause expressions reported. No scan covers prior
Git history. A fourth scan of the pinned SwiftSoup, LRUCache and swift-atomics
source archives covered 295 files without scanner errors. Its MIT/GPL match in
the SwiftSoup Google fixture led to the separate source-audit issue above; other
unknown-license-reference matches appeared in swift-atomics documentation and
pull request templates. The source archives, not their Git histories, were scanned.
ScanCode was the 33.0.0rc1 release candidate
using its 33.0.0rc1 license data, pluggy 1.5.0, and a locally built libmagic
5.48; it was run on macOS arm64. Automated detection does not determine rights
or replace review, and a new distribution must be checked separately.

With `--npm-tarballs`, the audit downloads the three lockfile URLs, verifies
their SHA-512 SRI values, and compares the installed regular-file contents with
the archives. On 17 November 2026 it checked 655 installed files; all three
package license files matched their retained copies. `npm audit --omit=dev
--ignore-scripts` reported zero known advisories for the three-package lockfile
at that time. This does not cover Swift dependencies or unknown vulnerabilities.

```sh
python3 Scripts/audit-dependencies.py --cmark-source /absolute/path/to/cmark-gfm --npm-tarballs
```

`--npm-tarballs` requires network access; omitting it explicitly reports that
the archive and installed-byte check was not performed. The reference checkout
must be at the pinned commit. The CI job requires the complete audit.

The locally generated CLI archive contains the executable, license inventory
and Node lockfile but not npm packages or spec fixtures. The mirror generator
does not export those spec fixtures. The current SwiftMD source snapshot does
include the four remaining fixtures and the full published snapshot; a Git
clone also contains earlier history with the two removed files. Review each
distribution's complete file set separately. Swift-Highlight 1.0.1 replaces
identified fixture quotations, while its older tag and Git history still retain
the originals. No statement here determines rights in those historic copies.

Before a public release, obtain independent review of the SVG policy and
deployment isolation, perform distribution-specific license/provenance review,
verify a candidate built from the final commit on clean target systems, and
recheck live vulnerability data and tag identities. Existing tests do not
substitute for these gates.
