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
