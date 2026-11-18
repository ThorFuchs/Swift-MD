#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare distributed notices and fixtures with pinned sources and npm archives."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
CHECKOUTS = ROOT / 'Adapters/SwiftMDBlocks/.build/checkouts'
NOTICE = ROOT / 'ThirdPartyLicenses'
FIXTURES = ROOT / 'Tests/SwiftMDTests/Fixtures/cmark-gfm'
CMARK = '27d942c8b0a62d192f616e5bf3578f4b6a89e180'
FIXTURE_HASHES = {
    'spec.txt': '7d8e5814befec287ac116786d81ff14e0adc9b13295b4494649e995408fd871c',
    'extensions.txt': 'a2a45e98be9fca95f564f927265a0f63beea6cae5369d1cf4bde44caa51b2a3a',
    'extensions-full-info-string.txt': 'dec5fc65880d74f97d5181e0b75466fbe12662cda8383d8b51fd78e06191092f',
    'extensions-table-prefer-style-attributes.txt': '3d902a4a1ce48df5dd7910647602fbae4535d8bac6700e918280fe1d928a4cee',
}
# Source checkout, lockfile identity, source notice, retained notice.
NOTICES = (
    ('Swift-GFM', 'swift-gfm', 'LICENSE', 'SwiftGFM-Apache-2.0.txt'),
    ('Swift-GFM', 'swift-gfm', 'NOTICE', 'SwiftGFM-NOTICE.txt'),
    ('Swift-GFM', 'swift-gfm', 'Vendor/GitHubCMark/COPYING', 'cmark-gfm-COPYING.txt'),
    ('Swift-Highlight', 'swift-highlight', 'LICENSE', 'SwiftHighlight-Apache-2.0.txt'),
    ('Swift-Highlight', 'swift-highlight', 'NOTICE', 'SwiftHighlight-NOTICE.txt'),
    ('Swift-Highlight', 'swift-highlight', 'THIRD_PARTY_NOTICES.md', 'SwiftHighlight-THIRD-PARTY.md'),
    ('Swift-Highlight', 'swift-highlight', 'Licenses/HighlightKit-MIT.txt', 'SwiftHighlight-HighlightKit-MIT.txt'),
    ('Swift-Highlight', 'swift-highlight', 'Licenses/highlight.js-BSD-3-Clause.txt', 'SwiftHighlight-highlight.js-BSD-3-Clause.txt'),
    ('SwiftSoup', 'swiftsoup', 'LICENSE', 'SwiftSoup-MIT.txt'),
    ('LRUCache', 'lrucache', 'LICENSE.md', 'LRUCache-MIT.txt'),
    ('swift-atomics', 'swift-atomics', 'LICENSE.txt', 'swift-atomics-Apache-2.0.txt'),
)
NPM_NOTICES = {'katex': 'KaTeX-MIT.txt', 'pele': 'Pele-MIT.txt', 'commander': 'commander-MIT.txt'}


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def require(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cmark-source', type=Path, help='independent upstream cmark-gfm Git checkout')
    parser.add_argument('--npm-tarballs', action='store_true', help='download and verify locked npm tarballs and installed bytes')
    args = parser.parse_args()
    pins = {p['identity']: p['state']['revision'] for p in json.loads(
        (ROOT / 'Adapters/SwiftMDBlocks/Package.resolved').read_text())['pins']}
    for checkout, identity, source, target in NOTICES:
        repo = CHECKOUTS / checkout
        require(git(repo, 'rev-parse', 'HEAD').decode().strip() == pins[identity], f'{identity}: checkout differs from lockfile')
        content = git(repo, 'show', pins[identity] + ':' + source)
        require(content == (NOTICE / target).read_bytes(), f'notice mismatch: {target}')
    print(f'Pinned Swift package notices: {len(NOTICES)}/{len(NOTICES)} byte-identical')

    for name, digest in FIXTURE_HASHES.items():
        content = (FIXTURES / name).read_bytes()
        require(hashlib.sha256(content).hexdigest() == digest, f'fixture checksum: {name}')
        if args.cmark_source:
            require(git(args.cmark_source, 'show', CMARK + ':test/' + name) == content, f'upstream fixture differs: {name}')
    fixture_license = git(CHECKOUTS / 'Swift-GFM', 'show', pins['swift-gfm'] + ':Tests/SwiftGFMTests/Fixtures/cmark-gfm/LICENSE')
    require(fixture_license == (FIXTURES / 'LICENSE').read_bytes(), 'fixture license differs from pinned SwiftGFM copy')
    if args.cmark_source:
        require(git(args.cmark_source, 'rev-parse', 'HEAD').decode().strip() == CMARK, 'independent cmark source HEAD mismatch')
    snapshot = (ROOT / 'Tests/PublishedGFM/gfm-0.29.html').read_bytes()
    require(hashlib.sha256(snapshot).hexdigest() == 'b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220', 'published snapshot checksum')
    print(f'cmark fixture checksums: {len(FIXTURE_HASHES)}/{len(FIXTURE_HASHES)}; independent source: {bool(args.cmark_source)}; fixture license and published snapshot checksum: OK')

    lock = json.loads((ROOT / 'Tools/NodeDependencies/package-lock.json').read_text())['packages']
    installed_root = ROOT / 'Tools/NodeDependencies/node_modules'
    installed_files = 0
    for name, notice in NPM_NOTICES.items():
        package = installed_root / name
        expected = lock['node_modules/' + name]
        metadata = json.loads((package / 'package.json').read_text())
        require(metadata['version'] == expected['version'] and metadata['license'] == expected['license'], f'npm identity mismatch: {name}')
        require((package / 'LICENSE').read_bytes() == (NOTICE / notice).read_bytes(), f'npm license mismatch: {name}')
        if args.npm_tarballs:
            with urllib.request.urlopen(expected['resolved'], timeout=30) as response:
                archive = response.read(32 * 1024 * 1024 + 1)
            require(len(archive) <= 32 * 1024 * 1024, f'npm archive too large: {name}')
            algorithm, encoded = expected['integrity'].split('-', 1)
            require(algorithm == 'sha512' and hashlib.sha512(archive).digest() == base64.b64decode(encoded, validate=True), f'npm integrity mismatch: {name}')
            with tarfile.open(fileobj=io.BytesIO(archive), mode='r:gz') as tar:
                for member in tar:
                    if member.isdir():
                        continue
                    require(member.isfile(), f'unexpected npm archive entry: {name}/{member.name}')
                    path = PurePosixPath(member.name)
                    require(path.parts and path.parts[0] == 'package' and '..' not in path.parts and member.size <= 32 * 1024 * 1024, f'unsafe npm entry: {member.name}')
                    source = tar.extractfile(member)
                    require(source is not None and source.read() == package.joinpath(*path.parts[1:]).read_bytes(), f'installed npm bytes differ: {name}/{path}')
                    installed_files += 1
    ofl = (NOTICE / 'KaTeX-SIL-OFL-1.1.txt').read_bytes()
    require(hashlib.sha256(ofl).hexdigest() == '8eea8287e5876b539670cadb82e99f9a7afddec6f6730811be1daf25d2e9bcfd', 'KaTeX OFL license checksum')
    katex_js = (installed_root / 'katex/dist/katex.js').read_text(encoding='utf-8')
    require("hyphenate and escape adapted from Facebook's React under Apache 2 license" in katex_js and
            'Licensed under the SIL Open Font License, Version 1.1.' in katex_js,
            'KaTeX bundled-code license markers changed; review notices')
    print('KaTeX embedded-code license markers and retained OFL text: OK')
    require(hashlib.sha256((NOTICE / 'Pele-esbuild-MIT.txt').read_bytes()).hexdigest() ==
            'b40ec5baec7bb34fa5b1c09521fa3cd52d5fad7adafed74932a2010d3612a681', 'Pele esbuild license checksum')
    print('Pele esbuild runtime license checksum: OK')
    print(f'npm package identities and licenses: {len(NPM_NOTICES)}/{len(NPM_NOTICES)}; tarball integrity and installed files: {installed_files if args.npm_tarballs else "not checked"}')
    print('Byte and provenance checks do not constitute legal advice or a completed rights review.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError, tarfile.TarError) as error:
        print(f'Dependency audit failed: {error}', file=sys.stderr)
        sys.exit(1)
