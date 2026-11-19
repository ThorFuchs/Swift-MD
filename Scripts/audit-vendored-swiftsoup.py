#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify the fixture-free SwiftSoup source snapshot and its module renames.

Without --upstream-source this verifies recorded hashes and the packaged MIT
license. The optional separate upstream Git checkout verifies every original
blob and exact allowed transformation against the pinned tree.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / 'Adapters/SwiftMDBlocks/Vendor/SwiftSoup'
REVISION = 'd86f244ed497d48012782e2f59c985a55e77b3f5'
TREE = '33ce5dc7a74bac14957780845869dd7f8e809e0d'


def git(repo, *args):
    return subprocess.check_output(['git', '-C', str(repo), *args])


def require(condition, message):
    if not condition:
        raise ValueError(message)


def audit(upstream=None):
    info = json.loads((VENDOR / 'UPSTREAM.json').read_text())
    require(info.get('upstream_repository') == 'https://github.com/scinfu/SwiftSoup.git' and
            info.get('upstream_version') == '2.11.3' and info.get('upstream_commit') == REVISION and
            info.get('upstream_sources_tree') == TREE and info.get('local_module') == 'SwiftMDSoup',
            'unexpected SwiftSoup provenance identity')
    entries = info['files']
    require(len(entries) == 56 and 'LICENSE' in entries, 'unexpected SwiftSoup source count')
    actual = {p.relative_to(VENDOR).as_posix() for p in VENDOR.rglob('*') if p.is_file()}
    require(actual == set(entries) | {'UPSTREAM.json', 'JSOUP-LICENSE.txt'}, 'unexpected or missing vendor files')
    require(not any(p.is_symlink() for p in VENDOR.rglob('*')), 'vendor contains a symbolic link')
    if upstream:
        require(git(upstream, 'rev-parse', REVISION + ':Sources').decode().strip() == TREE,
                'upstream Sources tree differs from pinned tree')
        listing = git(upstream, 'ls-tree', '-r', '--name-only', '-z', REVISION, '--', 'Sources', 'LICENSE')
        expected = {path.decode() for path in listing.split(b'\0') if path}
        require(expected == set(entries), 'vendor files differ from upstream source inventory')
    changed = 0
    for name, entry in entries.items():
        path = PurePosixPath(name)
        require(not path.is_absolute() and '..' not in path.parts and
                (name == 'LICENSE' or (len(path.parts) >= 2 and path.parts[0] == 'Sources')),
                f'forbidden vendor path: {name}')
        data = VENDOR.joinpath(*path.parts).read_bytes()
        require(hashlib.sha256(data).hexdigest() == entry['vendored_sha256'], f'vendored file changed: {name}')
        count = entry['module_qualifier_replacements']
        require(isinstance(count, int) and count >= 0, f'invalid rename count: {name}')
        changed += count
        if upstream:
            original = git(upstream, 'show', REVISION + ':' + name)
            require(hashlib.sha256(original).hexdigest() == entry['upstream_sha256'], f'upstream hash changed: {name}')
            expected_count = original.count(b'SwiftSoup.') if path.suffix == '.swift' else 0
            transformed = original.replace(b'SwiftSoup.', b'SwiftMDSoup.') if path.suffix == '.swift' else original
            require(expected_count == count and data == transformed, f'unapproved vendor edit: {name}')
    require(changed == 7, 'unexpected number of module qualifier substitutions')
    require((VENDOR / 'LICENSE').read_bytes() == (ROOT / 'ThirdPartyLicenses/SwiftSoup-MIT.txt').read_bytes(),
            'vendored SwiftSoup license differs from the retained notice')
    jsoup_license = (VENDOR / 'JSOUP-LICENSE.txt').read_bytes()
    require(hashlib.sha256(jsoup_license).hexdigest() == '12f89090b34132ac86980044fba5f6d45cfbc02c1eb08e0b53a22b7cb40be446' and
            jsoup_license == (ROOT / 'ThirdPartyLicenses/SwiftSoup-jsoup-MIT.txt').read_bytes(),
            'retained jsoup reference license differs')
    print(f'Vendored SwiftSoup: {len(entries)} files, {changed} module-qualifier substitutions; '
          f'independent upstream: {bool(upstream)}; no fixture files')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--upstream-source', type=Path)
    args = parser.parse_args()
    audit(args.upstream_source)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'Vendored SwiftSoup audit failed: {error}', file=sys.stderr)
        sys.exit(1)
