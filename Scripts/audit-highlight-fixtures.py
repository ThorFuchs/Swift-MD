#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare 17 Swift-Highlight fixtures with pinned HighlightKit/highlight.js blobs.

Supply separate Git checkouts, each containing the named commits. Byte identity
and upstream license notices document provenance; they do not establish who
owns every contribution or constitute a legal conclusion.
"""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SWIFT_HIGHLIGHT = '71d23c52a4afe154acdcc3b8aee968f0bf1b8564'
HIGHLIGHT_KIT = '524c185b0553756498c1b6a1765e8d119c4623a6'
HIGHLIGHT_KIT_IMPORT = 'b6c89dd5012d16a2d2dba44a2df758b474e81a59'
PINNED_HIGHLIGHT_JS = '08cb242e7d4aee787114eb04cc7ab18314d82f92'
FIXTURES = (
    ('ada/default', 'ada/default', '85b20421a2620b765508f16289e0592e0563cfcb'),
    ('cpp/function-like-keywords', 'cpp/function-like-keywords', '224d7fe20fb30bdce11fe0898b23157ab58d7cde'),
    ('csharp/floats', 'csharp/floats', '4d386f8ae885cc823596c30964568c07d1cf495b'),
    ('css/css_consistency', 'css/css_consistency', 'c7d99732227d6228aae13728a531f8e71849c76e'),
    ('diff/git-format-patch', 'diff/git-format-patch', 'e4cefdd6426ffa978091c0a6d000cedc3cf5e749'),
    ('go/numbers', 'go/numbers', '0f96a7815bcc676d225c88828bc0db6c0a9de416'),
    ('javascript/keywords', 'javascript/keywords', 'd21e285f0df83699d460798f28c489e00a7c7ae9'),
    ('leaf/default', 'leaf/default', '4745bf687c6ed2aa5104abedd41276da80d4a0fa'),
    ('less/css_consistency', 'less/css_consistency', 'c7d99732227d6228aae13728a531f8e71849c76e'),
    ('php/attributes', 'php/attributes', 'd86474408778cbb8f0c0a37404512bdb070c181d'),
    ('php/functions', 'php/functions', 'd86474408778cbb8f0c0a37404512bdb070c181d'),
    ('rust/numbers', 'rust/numbers', 'de8f765d6fc87de919dc6bcb32fb8a5cb74d47b8'),
    ('rust/sample1', 'rust/sample1', '22afbc0a7b2cee023debdc20ff67500ff7f91b21'),
    ('scss/css_consistency', 'scss/css_consistency', 'c7d99732227d6228aae13728a531f8e71849c76e'),
    ('stylus/css_consistency', 'stylus/css_consistency', 'c7d99732227d6228aae13728a531f8e71849c76e'),
    ('xml/non-ascii-attribute-names', 'xml/non-ascii-attribute-names', PINNED_HIGHLIGHT_JS),
    ('xml/non-ascii-element-names', 'xml/non-ascii-element-names', PINNED_HIGHLIGHT_JS),
)


def blob(repo, commit, path):
    return subprocess.check_output(['git', '-C', str(repo), 'show', f'{commit}:{path}'])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--highlightkit-source', required=True, type=Path)
    parser.add_argument('--highlightjs-source', required=True, type=Path)
    parser.add_argument('--swift-highlight-source', type=Path,
                        default=ROOT / 'Adapters/SwiftMDBlocks/.build/checkouts/Swift-Highlight')
    args = parser.parse_args()
    notices = ROOT / 'ThirdPartyLicenses'
    subprocess.run(['git', '-C', str(args.highlightkit_source), 'merge-base', '--is-ancestor',
                    HIGHLIGHT_KIT_IMPORT, HIGHLIGHT_KIT], check=True)
    if blob(args.highlightkit_source, HIGHLIGHT_KIT, 'LICENSE') != (notices / 'SwiftHighlight-HighlightKit-MIT.txt').read_bytes():
        raise ValueError('HighlightKit MIT notice differs')
    expected_license = (notices / 'SwiftHighlight-highlight.js-BSD-3-Clause.txt').read_bytes()
    license_commits = {entry[2] for entry in FIXTURES}
    imported_at = int(subprocess.check_output(['git', '-C', str(args.highlightkit_source), 'show',
                                               '-s', '--format=%ct', HIGHLIGHT_KIT_IMPORT]))
    for commit in sorted(license_commits):
        if blob(args.highlightjs_source, commit, 'LICENSE') != expected_license:
            raise ValueError(f'highlight.js license differs at {commit}')
        timestamp = int(subprocess.check_output(['git', '-C', str(args.highlightjs_source), 'show',
                                                 '-s', '--format=%ct', commit]))
        if timestamp >= imported_at:
            raise ValueError(f'highlight.js commit is not dated before the HighlightKit import: {commit}')
    exact = bom_only = 0
    for fixture, source, commit in FIXTURES:
        fixture_path = f'Tests/HighlightKitTests/Fixtures/{fixture}.code.txt'
        swift = blob(args.swift_highlight_source, SWIFT_HIGHLIGHT, fixture_path)
        kit = blob(args.highlightkit_source, HIGHLIGHT_KIT, fixture_path)
        if swift != kit:
            raise ValueError(f'HighlightKit bytes differ: {fixture}')
        if kit != blob(args.highlightkit_source, HIGHLIGHT_KIT_IMPORT, fixture_path):
            raise ValueError(f'HighlightKit initial import differs: {fixture}')
        js = blob(args.highlightjs_source, commit, f'test/markup/{source}.txt')
        if swift == js:
            exact += 1
        elif source.startswith('xml/') and js.startswith(b'\xef\xbb\xbf') and swift == js[3:]:
            bom_only += 1
        else:
            raise ValueError(f'highlight.js bytes differ beyond expected BOM: {fixture}')
    if (exact, bom_only) != (15, 2):
        raise ValueError('unexpected exact/BOM comparison counts')
    print(f'HighlightKit initial import and selected revision: {len(FIXTURES)}/17 exact; highlight.js: {exact} exact, {bom_only} differ only by UTF-8 BOM')
    print(f'Upstream license bytes match at {len(license_commits)} earlier-dated highlight.js revisions and the HighlightKit revision')
    print('Byte identity and declared licenses are evidence, not a legal determination of all contributors\' rights.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Fixture provenance audit failed: {error}', file=sys.stderr)
        sys.exit(1)
