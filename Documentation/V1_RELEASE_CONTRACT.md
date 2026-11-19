# SwiftMD 1.0 candidate contract

This is the proposed release contract, not evidence that 1.0 has been tagged
or published. The Core repository is the only development source; the optional
SwiftPM adapter package is generated from a reviewed Core repository commit.

## API and rendering

The `SwiftMD` Core product and the public Swift APIs in the generated adapter
products are intended to follow semantic versioning from their respective
1.0.0 tags. Deprecations and breaking changes require the appropriate version
change. Availability remains limited by the platform, runtime and trust
requirements of each API. New upstream renderer versions and serialized output
changes may occur in compatible releases; applications should test the HTML
profile they rely on rather than treat its exact bytes as a stable wire format.

The Core compiler without optional renderers returns the exact bytes produced
by SwiftGFM for the same configuration. This contract compares the two
implementations at the same configured versions; it does not freeze SwiftGFM's
output forever or claim complete GFM conformance. The extended block profile
may reserialize HTML and intentionally follows the policies described in the
[security contract](SECURITY_CONTRACT.md).

`SwiftMDBundled` supplies `SwiftMDIntegrated.render` for highlighting, `math`
code fences rendered as MathML and `mermaid` code fences rendered as validated
SVG. Rendering happens before the HTML reaches a browser; displaying its MathML
and SVG does not require client-side JavaScript. Unsupported languages and
renderer failures produce diagnostics. The caller must inspect diagnostics,
and supply page-unique SVG prefixes. `$$` block math, inline math and general
HTML or SVG sanitization are not part of this contract.

The Apple backend uses trusted bundled scripts in JavaScriptCore; the Linux
backend invokes a trusted, separately supplied absolute Node executable. These
backends do not establish hard time or aggregate memory bounds. Hostile input
requires the external deployment isolation described in the security contract.

## Platform evidence

Before tagging, test the final release commit and generated mirror on each
platform named as supported by the release. Historical evidence includes Linux
x86_64 execution, macOS arm64 execution, and iOS simulator execution. Simulator
execution is not a physical-device test. Package platform declarations or
successful cross-compilation alone are not runtime verification. Other Apple
platforms, architectures, browsers and operating systems are not implied by
those results. A release must publish its tested version, architecture and scope.

## Required release evidence

* Complete the distribution-specific license and provenance review, including
  the bundled scripts, notices, upstream source packages and existing history.
* Run the independent automated scan with its required-file coverage gate and
  review any findings; a clean scan is not a penetration test.
* Run Core, independent cmark-gfm, real three-renderer, mirror policy, isolated
  versioned consumer, CLI, release-build and deployment-isolation checks.
* Verify public upstream tags and lockfiles, test a locally generated mirror
  against synthetic tags, then verify the actual public tags and consumer
  after publication. Do not publish a local-test mirror or `file://` references.
* Ensure the mirror is generated only from the reviewed committed source; its
  source, lockfile, generated assets, notices and provenance must be traceable.

The [release preparation](RELEASE_PREPARATION.md) and
[security and license review](SECURITY_LICENSE_REVIEW.md) record the current
procedure and unresolved evidence. Publishing 1.0 requires a final decision on
those issues; this file does not substitute for that decision.
