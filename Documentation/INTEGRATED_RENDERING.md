# Integrated rendering prototype

SwiftMD's root product remains the byte-preserving Core. The local adapter
package now contains two experimental renderers over the same block processing
and SVG validation: `SwiftMDCompiler` uses Node on macOS/Linux, and
`SwiftMDJavaScriptCore` uses JavaScriptCore on Apple platforms. Both accept
trusted renderer code/configuration and return HTML plus block diagnostics.
The released 1.0.0 mirror uses the prior backend; this SwiftHTML integration is
currently a local development candidate.

`Scripts/generate-adapter-mirror.py --include-locked-renderers` additionally
prepares an experimental `SwiftMDBundled` product in the generated mirror. It
downloads the exact npm tarballs referenced by `Tools/NodeDependencies/package-lock.json`,
checks their SHA-512 integrity, extracts only the original KaTeX and Pele
renderer files and their license texts, and records their SHA-256 hashes and
archive identities in `MIRROR-ORIGIN.json`. No `node_modules` or generated
renderer files are committed to the source repository. Review the bundled
artifacts and complete third-party notice obligations before publishing a mirror.
Generation requires either `--local-test` or `--verify-public-dependencies`.
The latter checks public tags, revisions and published Core compatibility; it
does not itself authorize publication or replace legal and security review.

The intended consumer call is:

```swift
import SwiftMDBundled

let result = try SwiftMDIntegrated.render(
    markdown,
    svgPrefix: "unique-page-id",
    nodeExecutable: "/trusted/absolute/path/to/node" // Linux; omit on Apple
)
print(result.html)
for diagnostic in result.diagnostics { print(diagnostic.message) }
```

The initializer also allows a renderer to be reused on separate pages. Never
combine multiple outputs from the same fixed prefix on one page; use a distinct
prefix for each separately rendered fragment.

The adapter resolves public SwiftHTML 0.1.0, which contains the fixture-free
SwiftSoup 2.14.4 backend. A generated test mirror may also resolve an explicitly
synthetic, local-only tag. A public mirror must pass its own release gates.
KaTeX and Pele are bundled resources, not npm dependencies
installed by the consumer. Apple platforms use JavaScriptCore and do not need Node or a
WebView. Linux requires the explicitly supplied trusted Node executable. The
generated MathML and SVG need no client-side JavaScript. Both backends have
input and output checks but no hard execution deadline or aggregate memory
limit; JavaScriptCore executes in-process, so task cancellation does not stop
running JavaScript. The SVG allowlist is not a general sanitizer or security
audit. IDs require a prefix unique across the entire composed page.

Use `math` and `mermaid` code fences. Inline math and `$$` delimiters remain
unimplemented. Backend failures preserve an escaped source block and provide a
diagnostic rather than silently succeeding. A local mirror can be generated and
tested with synthetic tags; this does not publish a mirror, tag or release.

The local KaTeX backends also implement `MathMLRenderer.renderMath(literal:
displayMode:)` for callers that already have a TeX literal. Both Node and
JavaScriptCore pass that literal as data to KaTeX, use the same trust and
expansion settings as the fence adapter, and produce MathML in inline or
display mode. This low-level API does **not** recognize math in Markdown and
does not change the behavior of `SwiftMDIntegrated.render`.

An optional math-aware Markdown parser is needed before `$…$` and `$$…$$`
can be supported correctly. SwiftGFM's read-only AST and rendered HTML cannot
reconstruct original TeX after Markdown has consumed escapes, entities or
emphasis, and its source positions are not a lossless token mapping. Math
recognition must also define code and HTML exclusions, nested block containers,
link text and targets, and table-pipe precedence. A global regex or a search
through rendered text is not a reliable substitute. The unchanged Core path
must continue to return SwiftGFM's exact bytes.

As a bridge for a future trusted math-aware parser, `BlockCompiler` accepts an
ordered HTML/math document stream. It renders each TeX literal outside the
parser, processes other blocks, then inserts MathML without passing it through
HTML reserialization. Failed or empty math output retains the escaped original
delimited source and emits a diagnostic. The caller must supply trusted HTML
segments and only place math at HTML text or block positions, not in attributes
or comments. This bridge is not itself a Markdown parser or a sanitizer.

A local-only build flag, `SWIFTMD_EXPERIMENTAL_GFM_MATH`, connects this bridge
to an unreleased math-aware SwiftGFM prototype and to the one-call compiler and
CLI. This requires a separately edited local SwiftGFM checkout; the published
SwiftGFM dependency does not expose that API. Do not enable or distribute this
flagged build as a released package. The prototype rejects `allowUnsafeHTML`,
NUL input and unclosed display fences, and does not recognize mathematics in
table cells or image descriptions. Its syntax and parser edge cases remain
under test. In the ordinary build only the existing `math` fence is recognized.
For these math-parser document errors, SwiftMD emits the entire original
Markdown as escaped code plus a diagnostic; strict CLI mode emits no HTML.

On 19 November 2026, an isolated macOS ARM64 SwiftPM-edit build using local
SwiftGFM commit `67e12f43b859ec5e9801d7d32e46851c04e59836` passed 38 adapter
tests and six experimental CLI tests with real renderers. Node and
JavaScriptCore matched for the combined math/highlight/Mermaid document.
Chromium with page scripts disabled displayed inline math, display math,
fenced math and SVG with correct namespaces and measurable geometry; adjacent
combining Unicode was retained. The local SwiftGFM commit is unreleased and
does not constitute a public SwiftPM dependency or hosted CI evidence.

For a browser check of the direct Node backend's two MathML modes (not of
Markdown delimiter parsing), set trusted absolute Node and KaTeX paths and run:

```sh
SWIFTMD_NODE="$(command -v node)" \
SWIFTMD_KATEX="$PWD/Tools/NodeDependencies/node_modules/katex" \
swift run --package-path Tests/MathMLBrowserProbe MathMLBrowserProbe > /tmp/swiftmd-mathml-probe.json
SWIFTMD_NODE="$(command -v node)" \
SWIFTMD_MATHML_PROBE=/tmp/swiftmd-mathml-probe.json node Scripts/test-browser.mjs
```

The browser test disables page scripts and checks MathML namespaces, the
inline/display distinction and measurable geometry; it also exercises the
existing CLI's fenced math, syntax highlighting and SVG output.
On 19 November 2026 this probe passed in Chromium on macOS arm64 with page
scripts disabled. The 30 adapter tests passed in both debug and optimized
builds with the real Node and JavaScriptCore renderers; they compare the two
backends for both modes, including invalid TeX, input limits and disabled
untrusted link/image commands. These direct-renderer checks do not establish
support for Markdown math delimiters.

The same day `Scripts/test-all.sh` passed again on macOS against SwiftHTML
candidate `9ccb0f058c12c4a00d9b78585de2d06c01e0f672`, including the
independent cmark comparison and real renderer tests. Its known published-GFM
baseline deviations remain. SwiftHTML 0.1.0 was subsequently published.
The subsequent candidate `d669913150990db1b7637659f71bea5ac9a10876` changes
only SwiftHTML validation documentation; the 30 adapter tests and the license
and provenance checks passed again against that exact local commit on macOS.
The SwiftHTML session also tested that exact commit on native Linux ARM64:
14 debug and 14 release tests, release build, renamed-checkout example and a
synthetic versioned consumer passed. The final Linux consumer used a temporary
shell harness because an Ubuntu package download stalled; the checked-in
Python consumer test had passed for the preceding code-identical candidate.
The exact commit's macOS versioned consumer also passed. The x86-64 emulation
results apply to the preceding code-identical candidate: debug tests and release
build passed, an initial release-test build crashed the Swift compiler with
signal 4, and a clean single-job retry passed all 14 tests. The crash remains
unexplained and is not evidence of native x86-64 behavior.
From SwiftMD commit `7949e36fda16e8b61766298e8aa577b2cdb6d439`, all eight
mirror-policy tests and the fresh versioned Core, integrated adapter and
SwiftSoup-coexistence consumers passed with explicitly synthetic local tags.
The consumer check also verified the SwiftHTML Apache, SwiftSoup MIT and
vendored LRUCache MIT license resources in the built package.

On the same date, SwiftMD commit `0833067ad5a22c96aef3652c38f68b86f07fe964`
with SwiftHTML `9ccb0f058c12c4a00d9b78585de2d06c01e0f672` ran on native
Linux ARM64 with Swift 6.2.4 and Node 24.22.1. All 23 adapter tests passed,
including the real KaTeX inline/display mode test. The CLI debug build and
all seven CLI tests passed, as did the isolated synthetic mirror and consumer
test, including SwiftSoup coexistence. JavaScriptCore, browser and systemd
isolation were not part of this Linux run. This tests direct TeX rendering,
not `$` or `$$` Markdown recognition.

On 18 November 2026, an iOS 27.2 simulator ran a temporary app using the actual
local `SwiftMDJavaScriptCore` product, Swift-Highlight, KaTeX 0.19.1 and Pele
1.13.0. A GFM table, highlighted Swift, MathML, SVG and an invalid-math fallback
passed together. A second temporary app imported only the generated
`SwiftMDBundled` product from source commit `b8a9cd9` and passed the same
combined scenario with no app-supplied JavaScript files or Node installation.
An earlier independent JavaScriptCore probe exercised eight Pele diagram types.
These are simulator results, not physical-device or complete security-qualification
claims. On 18 November 2026, [Linux CI run 44339916549](https://github.com/ThorFuchs/Swift-MD/actions/runs/44339916549)
passed on source commit `def5d1c`, including the bundled Linux one-call
consumer with real Node, KaTeX, Pele and Swift-Highlight, the independent C
reference comparison, and the Linux resource and isolation tests. That run
does not establish iOS physical-device support or complete security review.

The simulator consumer is now reproducible from a clean committed source
checkout on macOS with Xcode, `xcodegen`, network access and one already booted
iOS simulator:

```sh
python3 Scripts/test-ios-consumer.py --simulator SIMULATOR-UDID
```

The script generates an explicitly local-only mirror, creates a disposable app
that imports only `SwiftMDBundled`, and checks real combined rendering and a
failure fallback inside the simulator. It uninstalls only its own uniquely
named test app. It does not create a remote mirror or publish a release.

## Local SwiftHTML integration verification (19 November 2026)

The implementation at SwiftMD commit `1e30ca12b869298074ad6d4f2168d4fd8f2941e7`
was tested with the separate SwiftHTML commit
`8bc39e2bd950c89f79fcb006ec552edee0926a2e` on macOS 27.3 arm64, Apple Swift
6.4.2, Node 26.5.0 and Chromium 157.0.8103.79:

* `Scripts/test-all.sh` passed 704 bundled cmark expectation cases and compared
  705 inputs byte-for-byte with an independently built cmark-gfm
  `27d942c8b0a62d192f616e5bf3578f4b6a89e180` C renderer. Two upstream-disabled
  cases and one `<IGNORE>` expectation remain separately skipped. The existing
  published GFM 0.29 analysis found 651/677 exact in the `all` profile; no
  complete GFM conformance is claimed.
* All 27 adapter tests passed with real Node and JavaScriptCore renderers,
  including exact code-literal whitespace, author-written raw HTML and
  fail-closed SVG cases. A subsequent adapter run with an additional regression
  for byte-preserving insertion of two validated SVG fragments passed all 28
  tests with no skips. Seven CLI tests passed in both debug and optimized
  builds. Swift 6.4.2 reports that the native SwiftPM build system used for the
  optimized build is deprecated.
* Chromium with page JavaScript disabled rendered MathML and two identical
  diagrams with SVG namespaces, `viewBox`, measurable geometry, distinct IDs,
  titles and descriptions. An iOS 27.2 simulator app using the generated
  `SwiftMDBundled` product passed the combined rendering and fallback test. The
  simulator test used public Core 0.1.0 and synthetic local SwiftHTML/mirror
  tags; it is not a physical-device result.
* A generated local-only mirror passed independent Core and adapter consumers,
  all three real renderers, license-resource checks and coexistence with a
  separately requested SwiftSoup. The SwiftMD, SwiftHTML and mirror tags used
  there were synthetic and existed only in disposable repositories. Eight
  mirror-policy tests passed, including rejection of the wrong SwiftHTML
  revision and blocking public generation without an approved stable tag.
* The provenance audit matched the two backend notice resources and eight
  pinned Swift notices; npm archive integrity and 655 installed files matched.
  `npm audit --omit=dev --ignore-scripts` reported zero known advisories at
  that time. These checks are not a legal or security audit.

## Linux ARM64 integration verification (19 November 2026)

The separate SwiftHTML session tested SwiftMD commit
`7b47a5a3c2660732fc408396ff79c3ea3370ac13` with SwiftHTML commit
`8bc39e2bd950c89f79fcb006ec552edee0926a2e` from clean, local Git bundles.
The host was an Apple Silicon Mac Studio; Colima used Apple's virtualization
framework for a native ARM64 Ubuntu 24.04.4 VM with Linux kernel 6.8.0-117.
Tests ran in an Ubuntu 24.04.5 container from the official Swift 6.2.4 image
`sha256:3459518b2e723a7c363d0f8cfa44fc796c77ecd8c18e92fd10e6f92dd78c0b12`,
with Swift 6.2.4 and Node 24.22.1. Node's downloaded distribution was checked
against the official SHA-256 list. This was not x86 emulation.

`Scripts/test-all.sh` completed successfully: 704 bundled cmark fixture
expectations, 705 inputs compared against a separately built cmark-gfm C
renderer at `27d942c8b0a62d192f616e5bf3578f4b6a89e180`, 22 Linux adapter
tests using the real Node renderers, seven CLI tests, five Linux limit tests
and 14 supervisor tests passed. The published
GFM comparison retained its known baseline deviations; this is not a claim of
complete GFM conformance. JavaScriptCore tests are not available on Linux.
SwiftHTML separately passed 14 debug tests, 14 release tests, a release build
and a release consumer on the same Linux ARM64 environment.

The optimized CLI build (`-Xswiftc -no-whole-module-optimization`) and all
seven CLI tests passed. Eight mirror-policy tests and `Scripts/test-distribution.py`
passed, including separate version-based Core and integrated adapter consumers,
all three real renderers and coexistence with an independently requested
SwiftSoup package. The SwiftMD, SwiftHTML and mirror tags used by this test
were synthetic, temporary and local to the container; no mirror was published.

No hosted SwiftMD CI run has been completed for this integration. A normal container
run does not establish the separately configured systemd/cgroup security
boundary. No browser test was run in this Linux environment. The
previously published 1.0.0 mirror still uses its original backend. The locally
copied license resources help package applications preserve notices; they do
not prove that every downstream static-binary distribution includes them.
