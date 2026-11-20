# Public release preparation

## Optional Markdown mathematics candidate

The normal build resolves the public SwiftGFM 1.1.0 release and exposes its
math-aware API through an explicit opt-in. Before publishing, re-run the full
Core/reference suite, real Node and JavaScriptCore adapters, strict CLI and
browser tests, Linux runtime tests, and fresh public versioned consumers for
the final SwiftMD and generated-mirror commits. Re-run the automated security
scan with coverage of the new SwiftGFM C bridge and SwiftMD integration; the
local Clang analysis and ASan checks do not replace that gate.
The SwiftMD security workflow prepares a marked local-only mirror with a
disposable Core tag for pre-release analysis, so scanning the candidate does
not require a release tag to exist first. It separately builds an archived
copy of the exact resolved SwiftHTML sources and requires key parser files in
the CodeQL extraction report. This scan mirror is never a release artifact;
the public-dependency and provenance gates still apply before publication.

The math profile recognizes inline and display math outside code, image
descriptions and GFM table cells. Unsafe raw HTML cannot be combined with the
math-aware parser: document-level parser errors produce escaped source and a
diagnostic, and strict CLI mode emits no output. Its delimiter/currency rules
are intentionally limited and do not claim universal Markdown-math parity.
An additive public math API generally calls for a SwiftMD minor release; choose
the final version after the compatibility review. The implementation, tested
commits and platform boundaries are documented in
[integrated rendering](INTEGRATED_RENDERING.md).

The 1.0 API, deployment and platform boundaries are recorded in the
[release contract](V1_RELEASE_CONTRACT.md) and
[security contract](SECURITY_CONTRACT.md).

This document records the release boundary and the checks needed to prepare a
candidate. It does not authorize a visibility change, tag, mirror publication,
GitHub release, or distribution of an archive.

SwiftMD is the sole source repository. The root SwiftPM product remains a
SwiftGFM wrapper without optional renderer dependencies. The block adapters,
Node renderers and CLI are maintained here. A separately generated adapter mirror
is the selected distribution design. The proposed
GFM 0.29 parser profile is still a design with a failing targeted gate, not a
feature: see [GFM029_PROFILE.md](GFM029_PROFILE.md).

## Distribution consumer gate

`Scripts/test-distribution.py` requires a clean committed checkout and a trusted
absolute path to Node. It fetches the lockfile-pinned KaTeX and Pele archives
and verifies their SHA-512 integrity while generating the test mirror. It creates
disposable local Git repositories, synthetic `1.0.0` tags for SwiftMD and its
generated mirror, and fresh version-based consumers using the real public
SwiftHTML release. The resolved SwiftHTML checkout must match the release revision in
`Adapters/SwiftMDBlocks/SwiftHTML-PROVENANCE.json`. It never creates
tags in the source repository or publishes a mirror. The mirror is generated
with `--local-test` and is marked unpublishable. The gate resolves the actual
public SwiftGFM and Swift-Highlight versions from the committed lockfile, checks
that normal consumers do not fetch SwiftSoup, tests coexistence with a separately
requested SwiftSoup package, and runs all three real renderers. The Core consumer is a separate
package and does not add the adapter dependencies. For containers with a
different UID, Git is told to trust only the selected source checkout and its
`.git` directory for the test subprocesses; no persistent global Git
configuration is changed.

```sh
SWIFTMD_NODE="$(command -v node)" \
python3 Scripts/test-distribution.py
```

This gate is distinct from `Scripts/test-all.sh`. Synthetic local tags do not
demonstrate a public SwiftHTML release. SwiftHTML 0.1.0 is public; the existing
SwiftMD 1.0.0 and 1.0.1 Core releases use the prior backend. This integration
uses SwiftHTML 0.1.0. Its own code is Apache-2.0, with retained MIT notices for its bundled dependencies;
review the actual distributed notices before publication. Verify each public tag, its commit,
dependency accessibility, mirror provenance and distribution licenses again.

The generator requires exactly one mode: `--local-test` explicitly marks its
output unpublishable and permits `file://` URLs; `--verify-public-dependencies`
requires canonical public HTTPS URLs and checks each SwiftPM tag against its
lockfile revision without configured Git credentials. It checks that the
source commit is advertised by the public SwiftMD repository and that the
released Core tag is an ancestor with an identical Core manifest and runtime
source; changes confined to `Sources/SwiftMD/SwiftMD.docc/` are allowed. These
checks do not establish legal clearance, security qualification or permission
to publish. `MIRROR-ORIGIN.json` records the checks and explicitly retains
`release_review_required: true`. Containerized Git operations trust only the
explicit source checkout for each invocation and do not modify global config.

For a disposable local test, `Scripts/test-distribution.py` verifies the public
SwiftHTML tag but keeps the generated mirror explicitly local. Public candidate generation requires
explicit `--swifthtml-url` and `--swifthtml-version` values and is fail-closed
if `public_repository` or `public_version` is unset in the provenance file.
A public-dependency candidate can be generated with:

```sh
python3 Scripts/generate-adapter-mirror.py /tmp/swiftmd-candidate \
  --core-version "$VERIFIED_SWIFTMD_CORE_VERSION" --gfm-version 1.1.0 --highlight-version 1.0.1 \
  --swifthtml-url "$VERIFIED_SWIFTHTML_URL" --swifthtml-version "$VERIFIED_SWIFTHTML_VERSION" \
  --verify-public-dependencies --include-locked-renderers
python3 Scripts/test-public-candidate.py /tmp/swiftmd-candidate --node "$(command -v node)"
```

The latter creates a disposable synthetic tag for the mirror only. Core,
SwiftGFM, Swift-Highlight and SwiftHTML must resolve from verified public tags.
Set `SWIFTMD_PUBLIC_CORE_VERSION` in the repository only when a compatible
public Core tag is available; the public-dependency CI gate uses that value.
Hosted jobs resolve the pinned public SwiftHTML release; they are not release
evidence for this branch until they run for its actual commit. The separate
synthetic local mirror test remains mandatory.

## Dependencies and current boundaries

* SwiftGFM 1.1.0 is public and resolves to commit
  `9a4176be3bda0953f4ddb91ec63de77d1ad230fa`. The tag and commit must be
  checked again before a real release. It is a
  Swift wrapper around C, and its parser output is not a sanitizer or a claim
  of full GFM conformance.
* Swift-Highlight 1.0.1 is public and resolves to commit
  `71d23c52a4afe154acdcc3b8aee968f0bf1b8564`. The upstream release changes the
  Linux registry's locking and replaces identified fixture quotations. Its
  targeted Linux TSan checks passed upstream, but do not establish general race
  freedom; historical fixture material remains in its Git history. See the
  included [third-party inventory](../ThirdPartyLicenses/README.md).
* SVG validation is a restrictive fail-closed policy, not a general sanitizer
  or independent security audit. Host HTML and CSS are separate trust boundaries.
  Node adapters do not themselves impose hard time, memory or live-output
  limits. The optional Linux worker helper has the narrower limitations in
  [status](STATUS.md).
* Platform claims require actual execution of the relevant Core, adapters and
  CLI. SwiftGFM's cross-builds alone do not establish adapter platform support.
  Browser evidence is focused Chromium coverage, not a cross-browser audit.
* An automated scan is not an independent expert audit of SVG or process
  isolation, and the provenance inventory is not an independent legal opinion.
  A local archive test is evidence only for its specific commit and architecture.

The published GFM 0.29 examples and cmark-gfm's bundled fixture suite are
separate corpora with separate provenance and licenses. Their documented
differences must not be represented as full GFM or GitHub.com conformance.
