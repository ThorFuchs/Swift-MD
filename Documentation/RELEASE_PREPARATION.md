# Public release preparation

This document records the release boundary and the checks needed to prepare a
candidate. It does not authorize a visibility change, tag, mirror publication,
GitHub release, or distribution of an archive.

SwiftMD is the sole source repository. The root SwiftPM product remains a
SwiftGFM wrapper without optional renderer dependencies. The block adapters,
Node renderers and CLI are experimental. A separately generated adapter mirror
is the selected distribution design, not a published package. The proposed
GFM 0.29 parser profile is still a design with a failing targeted gate, not a
feature: see [GFM029_PROFILE.md](GFM029_PROFILE.md).

## Distribution consumer gate

`Scripts/test-distribution.py` requires a clean committed checkout and trusted
absolute paths to Node, the installed KaTeX package and Pele module. It creates
disposable local Git repositories, synthetic `0.0.0` tags for SwiftMD and its
generated mirror, and **two fresh version-based consumers**. It never creates
tags in the source repository or publishes a mirror. The mirror is generated
with `--local-test` and is marked unpublishable. The gate resolves the actual
public SwiftGFM and Swift-Highlight versions from the committed lockfile, checks
that SwiftSoup 2.11.3 resolves to the locally tested revision, and runs all
three real renderers in the adapter consumer. The Core consumer is a separate
package and does not add the adapter dependencies. For containers with a
different UID, Git is told to trust only the selected source checkout and its
`.git` directory for the test subprocesses; no persistent global Git
configuration is changed.

```sh
(cd Tools/NodeDependencies && npm ci --ignore-scripts)
SWIFTMD_NODE="$(command -v node)" \
SWIFTMD_KATEX="$(pwd)/Tools/NodeDependencies/node_modules/katex" \
SWIFTMD_PELE="$(pwd)/Tools/NodeDependencies/node_modules/pele/dist/pele.js" \
python3 Scripts/test-distribution.py
```

The integration CI job runs this gate; it is distinct from the full test suite
in `Scripts/test-all.sh`. Synthetic local tags do not demonstrate that SwiftMD
or its adapter mirror is publicly available. Before publication, verify each
public tag, its commit, dependency accessibility, mirror provenance and the
distribution's licenses again, then test against the actual release identities.

## Dependencies and current boundaries

* SwiftGFM 1.0.1 is public and resolves to commit
  `2cb9450cf755858d338525fe64081b5f04864a2d`. Its annotated tag is unsigned;
  the tag and commit must be checked again before a real release. It is a
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
* Release packaging, independent SVG and resource-isolation review, and final
  license/fixture provenance review remain open. A local archive test from an
  earlier commit is evidence only for that commit and architecture.

The published GFM 0.29 examples and cmark-gfm's bundled fixture suite are
separate corpora with separate provenance and licenses. Their documented
differences must not be represented as full GFM or GitHub.com conformance.
