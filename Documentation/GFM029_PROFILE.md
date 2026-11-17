# Proposed opt-in GFM 0.29 profile

**Status: design and executable acceptance gate only. There is no selectable
profile or compatible backend yet.** The existing `MarkdownCompiler` continues
to return SwiftGFM's HTML byte for byte. Do not silently claim that the baseline
implements this proposed profile or silently fall back to it on profile errors.

## Scope and evidence

This proposal targets three specific rule groups in the independently preserved
[published GFM 0.29 specification](../Tests/PublishedGFM/README.md): XMPP
extended autolinks, numeric character references and inline HTML comments.
It does not claim full GFM 0.29 conformance. Other differences, configuration
conflicts and the exact published-fixture provenance are documented in
[the comparison](PUBLISHED_GFM_ANALYSIS.md).

The Swift-GFM and SwiftMD sessions independently examined the pinned parser.
In `src/inlines.c`, built-in handlers consume `&` and `<` before ordinary inline
extensions are tried. HTML block recognition also precedes block extensions.
The shared entity decoder is used in link destinations, titles and reference
definitions as well as text. The XMPP/email autolink extension runs in an AST
postprocessing phase and its resource boundaries differ from the published
examples. SwiftGFM does not expose the C extension-registration interface.

Postprocessing rendered HTML or the existing AST cannot reconstruct lost
information: `&#12345678;` and a literal U+FFFD have identical HTML and XML
AST output in the pinned backend. A malformed comment such as
`foo <!-- not -- *bold* --> end` is one HTML node there, whereas the published
rules require the inner emphasis to be parsed. Escaping that whole node would
still produce the wrong structure. Global Markdown regexes and source-range
guessing do not solve these contextual problems.

The inline-hook precedence was also tested against the independently built C
library: a real registered hook received the control character `Z`, but neither
`&` nor `<`. To reproduce against the separately checked-out and built pinned
source (verify its commit and rebuild it first):

```sh
cc -std=c99 -Wall -Wextra -I /path/to/cmark/src -I /path/to/cmark/build/src \
  Tests/PublishedGFM/cmark-extension-probe.c /path/to/cmark/build/src/libcmark-gfm.a \
  -o /tmp/swiftmd-extension-probe
/tmp/swiftmd-extension-probe
```

Expected: `observed: Z=1 ampersand=0 less-than=0`. This demonstrates that
specific hook's precedence, not the impossibility of every alternative.

## Proposed integration contract

* A future separately distributed, opt-in parser adapter owns an explicitly
  versioned backend and profile. It must perform the relevant recognition
  during parsing, with its GFM extensions and renderer exercised together.
  A separately maintained fork-compatible backend or another proven parser
  are possibilities; **neither has yet been selected or qualified**. No
  changes to SwiftGFM's vendored sources are implied.
* The default SwiftMD API remains unchanged. Profile selection must be explicit;
  unavailable backend, unsupported settings or parser failure must produce an
  error rather than silently switching to the baseline. Existing configuration
  semantics must be mapped explicitly, not guessed. The optional block pipeline
  may consume the resulting HTML only under its documented provenance and
  trusted-fragment policies; no claim of Markdown-fence provenance follows.
* Raw HTML, tagfilter, URL schemes and resource limits need separately named
  policies. Enabling raw HTML is not sanitization. Browser behavior, external
  resources and host CSS remain trust boundaries. Any C backend also needs
  symbol-isolation, concurrent-use, licensing and platform review.
* Pin the backend source and dependencies, expose the profile and parser
  identity, and test failures and concurrent use. Document input/output and
  actual resource limits; do not imply a timeout or memory limit exists.
* The adapter must remain optional: no new parser, Node, browser or Apple
  framework dependency may enter Core. Keep the SwiftGFM byte-parity tests.

## Executable acceptance gate

`Scripts/test-gfm029-profile.py` checks 46 cases: 22 selected published examples
and 24 explicitly identified additional probes. The latter test numerical
boundaries, literal Unicode, code, links and reference definitions, raw HTML
attributes, malformed comments in inline/list/blockquote contexts, and XMPP
inside code and an existing link. Expectations for additional cases are
derived from the published rules; they are not published fixture examples.
All cases use all five GFM extensions and `allowUnsafeHTML`, solely so their
HTML can be compared. This is **not a recommended security configuration**.

To audit the known baseline with a separately built, pinned C reference:

```sh
python3 Scripts/test-gfm029-profile.py \
  --candidate Tools/SwiftMDCLI/.build/debug/swift-md \
  --reference /absolute/path/to/pinned/cmark-gfm --expect-baseline
```

This audit succeeds only if all expected baseline differences and SwiftMD/C
parity remain unchanged; it explicitly does not pass the proposed profile. It
is included in `Scripts/test-all.sh`. The reference's source identity must be
verified by the caller; an executable's version string is insufficient.

To gate a future actual profile, supply a trusted executable adapter which
selects that profile, accepts UTF-8 Markdown on stdin and `--unsafe-html`, and
writes only HTML to stdout:

```sh
python3 Scripts/test-gfm029-profile.py --candidate /absolute/path/to/profile-adapter
```

This returns nonzero on every mismatch, execution failure or timeout. A pass
is necessary but not sufficient for adoption. Expand XMPP punctuation, slash,
`@`, escaped-character, HTML and competing-link cases; entity parsing in all
supported destinations/titles and invalid-codepoint cases; and comment block,
list, quote, HTML and code cases. Run the complete separately preserved 677-case
published comparison with explicit per-suite options, independent differential
tests, browser DOM and URL tests, regression/fuzz tests, and platform execution.
Report remaining differences rather than reducing the comparison to a score.
The test harness's ten-second subprocess timeout is a test guard, **not** a
runtime resource limit of SwiftMD or any proposed adapter.
