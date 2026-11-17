#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Gate a proposed opt-in GFM 0.29 parser profile; the baseline is not one."""
import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('analysis', ROOT / 'Scripts/analyze-published-gfm.py')
ANALYSIS = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ANALYSIS)

# These examples belong to the published GFM 0.29 snapshot. They are tested
# with all five GFM extensions and allowUnsafeHTML, not as a sanitization policy.
PUBLISHED = (*range(321, 331), *range(627, 636), 648, 649, 650)

# Additional regression cases and their expected HTML derived from the GFM
# rules. They are not presented as examples from the published corpus.
EXTRA = (
    ('decimal-seven', '&#0000065;\n', '<p>A</p>\n'),
    ('decimal-eight', '&#00000065;\n', '<p>&amp;#00000065;</p>\n'),
    ('decimal-nine', '&#000000065;\n', '<p>&amp;#000000065;</p>\n'),
    ('hex-six', '&#x000041;\n', '<p>A</p>\n'),
    ('hex-seven', '&#x0000041;\n', '<p>&amp;#x0000041;</p>\n'),
    ('hex-eight', '&#x00000041;\n', '<p>&amp;#x00000041;</p>\n'),
    ('hex-nine', '&#x000000041;\n', '<p>&amp;#x000000041;</p>\n'),
    ('invalid-codepoint', '&#x110000; &#0;\n', '<p>� �</p>\n'),
    ('literal-replacement-character', '�\n', '<p>�</p>\n'),
    ('literal-emoji', '😀\n', '<p>😀</p>\n'),
    ('entity-inline-code', '`&#00000065;`\n', '<p><code>&amp;#00000065;</code></p>\n'),
    ('entity-code-fence', '```\n&#00000065;\n```\n', '<pre><code>&amp;#00000065;\n</code></pre>\n'),
    ('entity-escaped', '\\&#00000065;\n', '<p>&amp;#00000065;</p>\n'),
    ('entity-link-destination', '[x](/p&#00000065;)\n', '<p><a href="/p&amp;#00000065;">x</a></p>\n'),
    ('entity-link-title', '[x](/p "&#00000065;")\n', '<p><a href="/p" title="&amp;#00000065;">x</a></p>\n'),
    ('entity-reference-destination', '[x][r]\n\n[r]: /p&#00000065;\n', '<p><a href="/p&amp;#00000065;">x</a></p>\n'),
    ('entity-raw-html-attribute', '<span title="&#00000065;">x</span>\n', '<p><span title="&#00000065;">x</span></p>\n'),
    ('invalid-comment-inline-markup', 'foo <!-- not -- *bold* --> end\n', '<p>foo &lt;!-- not -- <em>bold</em> --&gt; end</p>\n'),
    ('invalid-comment-blockquote', '> foo <!-- not -- *bold* --> end\n', '<blockquote>\n<p>foo &lt;!-- not -- <em>bold</em> --&gt; end</p>\n</blockquote>\n'),
    ('invalid-comment-list', '- foo <!-- not -- *bold* --> end\n', '<ul>\n<li>foo &lt;!-- not -- <em>bold</em> --&gt; end</li>\n</ul>\n'),
    ('comment-inline-code', '`<!-- not -- comment -->`\n', '<p><code>&lt;!-- not -- comment --&gt;</code></p>\n'),
    ('xmpp-inline-code', '`xmpp:foo@bar.baz/txt@bin`\n', '<p><code>xmpp:foo@bar.baz/txt@bin</code></p>\n'),
    ('xmpp-fenced-code', '```\nxmpp:foo@bar.baz/txt@bin\n```\n', '<pre><code>xmpp:foo@bar.baz/txt@bin\n</code></pre>\n'),
    ('xmpp-existing-link', '[xmpp:foo@bar.baz/txt@bin](/target)\n', '<p><a href="/target">xmpp:foo@bar.baz/txt@bin</a></p>\n'),
)


def run(command, source):
    result = subprocess.run(command, input=source.encode('utf-8'), capture_output=True, timeout=10)
    if result.returncode:
        raise RuntimeError(f'{command[0]} exited {result.returncode}: {result.stderr.decode("utf-8", "replace")}')
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True,
                        help='executable selecting the proposed profile; accepts --unsafe-html and stdin')
    parser.add_argument('--reference', type=Path,
                        help='optional independent pinned cmark-gfm; compare candidate bytes against it')
    parser.add_argument('--expect-baseline', action='store_true',
                        help='audit known baseline deviations; this is NOT a profile conformance pass')
    options = parser.parse_args()
    if options.expect_baseline and not options.reference:
        parser.error('--expect-baseline requires --reference')
    items = ANALYSIS.examples()  # verifies checksum and complete example inventory
    cases = [(f'published-{n}', ANALYSIS.text(items[n-1], 'language-markdown'),
              ANALYSIS.text(items[n-1], 'language-html')) for n in PUBLISHED] + list(EXTRA)
    failures, different_from_c = [], []
    for name, source, expected in cases:
        actual = run([str(options.candidate.resolve()), '--unsafe-html'], source)
        if actual != expected.encode('utf-8'):
            failures.append(name)
            print(f'FAIL {name}: expected {expected!r}, got {actual.decode("utf-8", "replace")!r}')
        if options.reference:
            command = [str(options.reference.resolve()), '--unsafe']
            for extension in ANALYSIS.EXTENSIONS:
                command += ['-e', extension]
            reference = run(command, source)
            if actual != reference:
                different_from_c.append(name)
    print(f'Specified cases: {len(cases) - len(failures)}/{len(cases)} exact')
    if options.reference:
        print(f'Candidate versus independent C: {len(cases) - len(different_from_c)}/{len(cases)} exact')
    if options.expect_baseline:
        known = {'published-324', 'published-634', 'published-635', 'published-649', 'published-650',
                 'decimal-eight', 'hex-seven', 'hex-eight', 'entity-link-destination', 'entity-link-title',
                 'entity-reference-destination', 'invalid-comment-inline-markup',
                 'invalid-comment-blockquote', 'invalid-comment-list'}
        if set(failures) != known or (options.reference and different_from_c):
            print('Baseline changed; investigate before updating the audit.', file=sys.stderr)
            return 1
        print('Baseline audit matches known deviations. This is NOT a conforming profile.')
        return 0
    if failures:
        print('Profile gate FAILED; no fallback to baseline counts as success.', file=sys.stderr)
        return 1
    print('Targeted profile gate passed; this does not establish complete GFM conformance.')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print(f'Profile gate error: {error}', file=sys.stderr)
        sys.exit(2)
