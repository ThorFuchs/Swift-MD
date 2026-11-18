# Status and verification

For current dependencies, the version-based consumer gate, and remaining
release boundaries see [release preparation](RELEASE_PREPARATION.md). The
dated sections below describe historical runs and dependencies at those times.

## SwiftGFM 1.0.1 integration (18 November 2026)

The public annotated `1.0.1` tag resolves to
`2cb9450cf755858d338525fe64081b5f04864a2d`; all three manifests and
lockfiles select it. Compared with `1.0.0`, the executable wrapper and
vendored parser are unchanged. The new source snapshot omits the two fixtures
whose individual rights remain unresolved; the old tag and Git history remain.

On macOS arm64 with Swift 6.4.2, `Scripts/test-all.sh` passed with the
independently built pinned C executable: 704 fixture expectations, 705 C
comparisons, 13 neutral expectations and 13 independent neutral comparisons,
16 adapter tests and seven CLI tests. Two upstream-disabled cases and one
`<IGNORE>` expected-output assertion were skipped. The separate published
GFM audit found 651/677 exact and the experimental profile 32/46 exact;
neither is a conformance pass. The pinned notice, fixture and npm integrity
audit also passed. Linux and distribution results must be tied to their own
tested commits and hosts.

## Swift-Highlight 1.0.1 integration (17 November 2026)

The public annotated `1.0.1` tag resolves to
`71d23c52a4afe154acdcc3b8aee968f0bf1b8564`. The adapter manifest and both
adapter/CLI lockfiles select that commit. The upstream Apache license and
NOTICE were verified byte-for-byte, and the updated third-party notice was
copied from that tag. Upstream's targeted Linux Thread Sanitizer workflow
passed for this commit; this does not establish general race freedom or a
completed legal review of historical fixture material.

On macOS arm64 with Swift 6.4.2 and Node 26.5.0, `Scripts/test-all.sh` passed
with the separately built pinned C reference: 746 fixture expectations, 747
independent comparisons, 16 adapter tests and seven CLI tests. The two
upstream-disabled examples and the `<IGNORE>` expected-output case remain
separately skipped as described below. The published GFM audit still reports
651/677 exact; this is not a conformance pass. The targeted profile audit
found the known 14 mismatches among 46 cases and 46/46 SwiftMD/C parity.
Chromium with page JavaScript disabled passed the combined GFM, highlighting,
MathML and SVG checks, including geometry, IDs and accessibility references.
These are macOS results, not a claim for other hosts or browser engines.

The new distribution gate also passed on macOS arm64 against disposable source
snapshot `6c047af6f75cfa18cc6f13e8c8e6feb786d15c43`: a Core-only consumer and
a separate generated-mirror consumer both ran; the latter invoked all three real
renderers and resolved the public SwiftGFM 1.0.0 and Swift-Highlight 1.0.1 tags.
SwiftMD and mirror tags were synthetic, local and discarded after the test.
This snapshot included the gate and dependency changes; it was not a release.

Core now selects SwiftGFM 1.0.1 at `2cb9450cf755858d338525fe64081b5f04864a2d`,
whose cmark-gfm backend is `0.29.0.gfm.13` at
`27d942c8b0a62d192f616e5bf3578f4b6a89e180`. SwiftGFM is Swift around C.
The independently published GFM specification examples have also been compared
separately; their selected-profile byte comparison has known differences, so no
complete GFM conformance claim is made.

The four retained, unmodified cmark-gfm fixtures and their licenses and hashes
are in `Tests/SwiftMDTests/Fixtures/cmark-gfm`. The test compares 704 enabled
examples with expected HTML. Two upstream-disabled examples are skipped; the
`<IGNORE>` example has no expected-output assertion. The optional independent
executable comparison includes it, for 705 cases. Thirteen separately authored
neutral cases and their thirteen independent C comparisons are counted separately;
they are not claimed as a complete replacement for the 42 removed examples.
Without a configured reference, the comparison is explicitly skipped;
`Scripts/test-all.sh` requires it. Build the *upstream* C program at the backend commit with CMake and run:

```sh
git clone https://github.com/github/cmark-gfm.git /tmp/cmark-reference
git -C /tmp/cmark-reference checkout --detach 27d942c8b0a62d192f616e5bf3578f4b6a89e180
cmake -S /tmp/cmark-reference -B /tmp/cmark-reference/build -DCMARK_TESTS=OFF
cmake --build /tmp/cmark-reference/build -j 4
SWIFTMD_CMARK_REFERENCE=/tmp/cmark-reference/build/src/cmark-gfm swift test --filter independentReference
```

All fixtures enable `allowUnsafeHTML` to match their expectations. Extensions
and footnotes are enabled for the extension and table-style suites; per-example
flags add individual extensions. Smart punctuation, full info string and table
style options apply only to their respective suites. These are test settings,
not sanitizer recommendations. The reference process receives corresponding
upstream CLI flags and is not the vendored library linked into SwiftMD.

The separately preserved published GFM 0.29 HTML at `Tests/PublishedGFM` has
677 examples. `Scripts/test-published-gfm.py` extracted and compared them on
17 November 2026 using the standard five-extension GFM profile and
`allowUnsafeHTML`: 651 byte-identical, 26 different, exit status 1. This includes
raw tagfilter differences and checkbox serialization differences, as well as
other cases involving renderer and parser behavior. The published examples are
not the bundled cmark fixture suite. The output comparison is byte-based, not
an assessment of semantic equivalence. See [the detailed case analysis](PUBLISHED_GFM_ANALYSIS.md)
and `Tests/PublishedGFM/README.md`.

## Executed locally on 17 November 2026

A Linux ARM64 VM ran Ubuntu 24.04, kernel 6.8.0-147, Swift 6.2.4 and
Node 24.22.1. `Scripts/test-all.sh`, with an independently built reference
executable, passed two Core XCTest cases, all 746 expected-output fixture
cases, 747 independent C comparisons, 14 adapter XCTest cases and seven CLI
integration tests. After the final SVG size-limit change, the adapter and CLI
suites were rerun and passed. A separate `swift build -c release -j 2
-Xswiftc -no-whole-module-optimization` also built the CLI, and its seven CLI
tests passed against that binary. No static-link or standalone archive test was
performed. Dependencies came from the pinned lockfiles;
the private Swift-Highlight source was supplied to the VM from an isolated
local Git mirror. This verifies Linux **aarch64**, not Linux x86_64.

On macOS arm64, Swift 6.4.2 and Node 26.5.0, 16 adapter tests passed after
updating Swift-Highlight to 1.0.0.
Chrome 157.0.8103.79 rendered a combined document with page JavaScript disabled.
The automated test verified table and highlighting, MathML and SVG namespaces,
`viewBox`, nonzero layout and path geometry, two distinct diagram IDs, title
and description references, and absence of additional network requests. A page
script sentinel confirmed that page scripts did not execute. This is a focused
Chromium test, not a cross-browser or complete visual-accessibility audit.

Reproduce the browser test on macOS after building the CLI and installing npm
dependencies with:

```sh
node Scripts/test-browser.mjs
```

Set `SWIFTMD_CHROME` to a Chromium executable on another host, and optionally
`SWIFTMD_BROWSER_SCREENSHOT` to a local PNG path. The test requires Python 3 and
a Node version with a built-in WebSocket implementation. No WASI, iOS or other architecture
execution is implied.

Linux process-limit tests ran on the Ubuntu 24.04 ARM64 VM: Node inherited
`RLIMIT_AS` and `RLIMIT_FSIZE`; allocations and file writes over the configured
per-process limits failed; and a deadline killed a worker and its ordinary
child in the same process group. `Scripts/run-linux-constrained.sh` supplies
these optional limits for a whole CLI worker. They do not bound aggregate
memory, prevent descendants leaving the process group, or provide a sandbox.
A kill can leave temporary files. The in-process Node adapters still do not
supply these bounds themselves; stronger isolation requires cgroups and OS
sandboxing. This helper has not been validated on macOS or Linux x86_64.

At the time of this run, release work remained: independently review the SVG policy and process isolation,
extend adversarial and cross-browser coverage, run other claimed platforms,
verify the generated adapter distribution mirror with released versions and consumers,
complete hosted CI for the final commit, and review release packaging. Swift-Highlight
1.0.0 is public at commit 326a0085c05931b868f5bff084d51eca7584aad7; its
Linux TSan findings remain unclassified and fixture provenance still requires
review. SwiftGFM 1.0.0 is public, and its annotated tag resolves to the previously
tested backend-wrapper commit d1c262f42daa7a06f4612a94671e10740e26d09a.
The manifests then used an exact version requirement. The CI integration job no
longer required a private Swift-Highlight secret; hosted execution for those
particular changes had not yet been verified at the time of this record.

## Hosted CI evidence

The GitHub Actions run for SwiftMD commit
`c441d526608b0c62abd9e3cbc029a24583a08731` completed successfully for both
Core and integration on Linux x86_64 with Swift 6.2.4, including the 747-case
independent C reference, real renderers, CLI and Linux process-limit tests.
The result applies to that commit, not automatically to later changes.

## Local release-candidate verification (17 November 2026)

The source commit `468106c5a7acca2acdc7c230d13ec7b802062301` produced a local
Linux aarch64 archive with `Scripts/build-linux-candidate.sh`. The archive is
`.artifacts/SwiftMD-linux-arm64-candidate-468106c.tar.gz` and has SHA-256
`c2dc65f79193b39c1f6d3dc174d3023155645c74d51140f700de9e4dc124a8db`.
It contains the executable, source and build identity, checksums, notices,
Swift runtime license, and npm lockfile. Node and npm dependencies are not bundled.
It is a local candidate, not a release, and its license inventory still needs a
final distribution review.

A fresh debootstrap Ubuntu 24.04 ARM64 chroot with no Swift toolchain verified
all archive checksums and ran seven CLI tests after installing Node 24.22.1,
the locked npm packages (`npm ci --ignore-scripts`), and system libraries.
`ldd` showed glibc, libstdc++, libgcc, libxml2, ICU 74, zlib and liblzma. This
was an ARM64 VM and chroot, not a separate machine or an x86_64 test.

The static Swift runtime link emitted a warning about `mktemp` in Foundation.
The Swift 6.2.4 [Foundation source](https://github.com/swiftlang/swift-foundation/blob/swift-6.2.4-RELEASE/Sources/FoundationEssentials/Data/Data%2BWriting.swift)
shows `mktemp` followed by `O_CREAT | O_EXCL`, with retries after `EEXIST`.
This identifies the warning's mechanism; it is not an independent security
audit or a general conclusion about safety.

After the Swift-Highlight 1.0.0 update, Linux ARM64 ran the full gate: 746
fixture expectations, 747 independently built C-reference comparisons, 16
adapter tests, seven CLI tests and four Linux worker-limit tests passed. The
combined CLI also ran all three real renderers under the worker limits. A
fresh local-path Core consumer and a separate generated-mirror consumer passed;
the latter used clearly marked local synthetic SwiftGFM and SwiftMD version
tags, not public releases. No mirror was published.

## Stable dependency follow-up (17 November 2026)

SwiftGFM's real annotated `1.0.0` tag object
`8b0b2ff7b5f589280e12f5fb3a300e1bdd9abaa7` points to
`d1c262f42daa7a06f4612a94671e10740e26d09a`, the previously tested commit.
Swift-Highlight's public `1.0.0` tag points to
`326a0085c05931b868f5bff084d51eca7584aad7`. All three SwiftMD manifests and
lockfiles use those exact versions. After this change the macOS and Linux
ARM64 gates each passed 746 fixture expectations, 747 independent C comparisons,
16 adapter tests and seven CLI tests; Linux also passed four process-limit
tests. Chromium passed the no-page-JavaScript test, and a real three-renderer
Linux invocation also passed under the optional worker limits.

A fresh version-based Linux Core consumer resolved the real public SwiftGFM
1.0.0 tag and ran successfully. A generated local mirror passed 16 adapter tests;
a separate versioned consumer resolved both actual public 1.0.0 tags and ran
all three renderers. SwiftMD and mirror version tags in these tests were
synthetic and existed only in disposable local repositories. No adapter mirror
or SwiftMD version was published.

The updated local archive
`.artifacts/SwiftMD-linux-arm64-candidate-4376c35.tar.gz` was built from
`4376c35da1fa531b2a693628e5395970515d82ef`, SHA-256
`ede37a5d7c591ae927990c63096384a691726512ef85d4f3efba5da0ca7b293f`.
A second fresh Ubuntu 24.04 ARM64 chroot without a Swift toolchain verified its
checksums and passed all seven CLI tests with separately installed Node, npm
packages and system libraries. It remains an unpublished candidate; the same
Foundation `mktemp` linker warning and license-review limitations apply.

## Adapter distribution generator

`Scripts/generate-adapter-mirror.py` exports only committed files from a clean
checkout into a new directory and records the source commit and dependency
requirements. It creates no repository or publication. Stable dependency
versions must be verified against their actual release commits before distribution.
The `--local-test` mode marks its output as never publishable and is the only
mode permitting `file://` dependency URLs. A temporary mirror generated from a
committed test snapshot passed 12 adapter tests against artificial local tags;
a separate version-based consumer built and executed all three renderers against
those artificial tags. This is not a released mirror or a verification of real
public versions.
