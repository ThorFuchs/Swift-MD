# Status and verification

Core passes through SwiftGFM at `d1c262f42daa7a06f4612a94671e10740e26d09a`,
whose cmark-gfm backend is `0.29.0.gfm.13` at
`27d942c8b0a62d192f616e5bf3578f4b6a89e180`. SwiftGFM is Swift around C.
The independently published GFM specification corpus has not been tested;
no complete GFM conformance claim is made.

The six unmodified cmark-gfm fixtures and their licenses and hashes are in
`Tests/SwiftMDTests/Fixtures/cmark-gfm`. The test compares 746 enabled examples
with expected HTML. Two upstream-disabled examples are skipped; the `<IGNORE>`
example has no expected-output assertion. The optional independent executable
comparison includes it, for 747 cases. Build the *upstream* C program at the backend commit with CMake and run:

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

On macOS arm64, Swift 6.4.2 and Node 26.5.0, the 14 adapter tests also passed.
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
`SWIFTMD_BROWSER_SCREENSHOT` to a local PNG path. The test requires a Node version
with a built-in WebSocket implementation. No WASI, iOS or other architecture
execution is implied.

Release work remains: independently review the SVG policy and process isolation,
extend adversarial and cross-browser coverage, run other claimed platforms,
verify the generated adapter distribution mirror with released versions and consumers,
and run the checked-in CI on GitHub and build release packaging. Swift-Highlight is currently private
and has no release tag; SwiftGFM has no 1.0.0 tag. Its revision requirement
prevents a stable version-based SwiftPM consumer. Do not replace it with a
version until the actual public tag and commit are verified. The CI integration job requires a repository secret granting read access to the private Swift-Highlight repository; its hosted execution is unverified. No release, tag,
remote mirror or push is performed by this work.

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
