#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise a verified local mirror with the real public Core and upstream tags.

Only the mirror's own 0.0.0 tag is synthetic, inside a disposable repository.
Nothing is published; this does not constitute a license or security review.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def run(*args, cwd=None):
    subprocess.run(args, cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('candidate', type=Path)
    parser.add_argument('--node', type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    node = args.node.resolve()
    origin = json.loads((candidate / 'MIRROR-ORIGIN.json').read_text())
    if origin.get('local_test_only') is not False or origin.get('release_review_required') is not True:
        raise ValueError('candidate must have public-dependency preflight and retain the review requirement')
    tags = origin['verified_public_tags']
    if set(tags) != {'swift-md', 'swift-gfm', 'swift-highlight', 'lrucache', 'swift-atomics'}:
        raise ValueError('candidate did not verify all public Swift dependency tags')
    if origin.get('vendored_swiftsoup', {}).get('revision') != 'd86f244ed497d48012782e2f59c985a55e77b3f5':
        raise ValueError('candidate has unexpected vendored SwiftSoup provenance')
    manifest = (candidate / 'Package.swift').read_text()
    if 'file://' in manifest or 'LOCAL TEST ONLY' in manifest or 'github.com/scinfu/SwiftSoup' in manifest or not node.is_file():
        raise ValueError('candidate cannot use file dependencies and Node must exist')
    if any(path.is_symlink() for path in candidate.rglob('*')):
        raise ValueError('candidate must not contain symbolic links')
    vendor = candidate / 'Adapters/SwiftMDBlocks/Vendor/SwiftSoup'
    vendor_info = json.loads((vendor / 'UPSTREAM.json').read_text())
    if vendor_info.get('upstream_commit') != origin['vendored_swiftsoup']['revision']:
        raise ValueError('vendored SwiftSoup provenance mismatch')
    expected = set(vendor_info['files']) | {'UPSTREAM.json', 'JSOUP-LICENSE.txt'}
    actual = {p.relative_to(vendor).as_posix() for p in vendor.rglob('*') if p.is_file()}
    if actual != expected or any('fixture' in p.lower() or 'corpus' in p.lower() for p in actual):
        raise ValueError('unexpected SwiftSoup files in the candidate')
    for name, details in vendor_info['files'].items():
        if hashlib.sha256((vendor / name).read_bytes()).hexdigest() != details['vendored_sha256']:
            raise ValueError(f'candidate vendored SwiftSoup hash mismatch: {name}')
    if (vendor / 'LICENSE').read_bytes() != (candidate / 'ThirdPartyLicenses/SwiftSoup-MIT.txt').read_bytes():
        raise ValueError('candidate SwiftSoup license mismatch')
    if (vendor / 'JSOUP-LICENSE.txt').read_bytes() != (candidate / 'ThirdPartyLicenses/SwiftSoup-jsoup-MIT.txt').read_bytes():
        raise ValueError('candidate jsoup reference license mismatch')
    assets = candidate / 'Adapters/SwiftMDBlocks/Sources/SwiftMDBundled/RendererAssets'
    for package in ('katex', 'pele'):
        for name, digest in origin['renderer_resources'][package]['files_sha256'].items():
            if Path(name).name != name or hashlib.sha256((assets / name).read_bytes()).hexdigest() != digest:
                raise ValueError(f'candidate renderer resource hash mismatch: {name}')
    with tempfile.TemporaryDirectory(prefix='swiftmd-public-candidate-') as name:
        temp = Path(name)
        mirror = temp / 'Swift-MD-Adapters'
        shutil.copytree(candidate, mirror, symlinks=False)
        run('git', 'init', '--quiet', cwd=mirror)
        run('git', 'add', '.', cwd=mirror)
        run('git', '-c', 'user.name=SwiftMD candidate test', '-c', 'user.email=invalid@example.invalid',
            'commit', '--quiet', '-m', 'Disposable candidate test', cwd=mirror)
        run('git', 'tag', '0.0.0', cwd=mirror)
        consumer = temp / 'Consumer'
        (consumer / 'Sources/Consumer').mkdir(parents=True)
        (consumer / 'Package.swift').write_text(f'''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "Consumer", platforms: [.macOS(.v15)], dependencies: [
    .package(url: {json.dumps(mirror.as_uri())}, exact: "0.0.0")
], targets: [.executableTarget(name: "Consumer", dependencies: [
    .product(name: "SwiftMDBundled", package: "Swift-MD-Adapters")])])
''')
        (consumer / 'Sources/Consumer/main.swift').write_text('''import Foundation
import SwiftMDBundled
let input = "```swift\\nlet value = 1\\n```\\n\\n```math\\nx^2\\n```\\n\\n```mermaid\\nflowchart LR\\nA-->B\\n```\\n"
let result = try SwiftMDIntegrated.render(input, svgPrefix: "candidate", nodeExecutable: ProcessInfo.processInfo.environment["SWIFTMD_NODE"]!)
precondition(result.diagnostics.isEmpty && result.html.contains("hljs-keyword") && result.html.contains("<math") && result.html.contains("<svg") && !result.html.contains("<script"))
print("Verified candidate consumer: all three real renderers passed")
''')
        env = os.environ.copy()
        env['SWIFTMD_NODE'] = str(node)
        subprocess.run(['swift', 'run', '--package-path', str(consumer), '-j', '4', 'Consumer'], check=True, env=env)
        resolved = {p['identity']: p['state'] for p in json.loads((consumer / 'Package.resolved').read_text())['pins']}
        if 'swiftsoup' in resolved or any(p.name.lower() == 'swiftsoup' for p in (consumer / '.build/checkouts').iterdir()):
            raise ValueError('consumer unexpectedly downloaded the external SwiftSoup package')
        for identity, expected in tags.items():
            actual = resolved[identity]
            if actual.get('version') != expected['version'] or actual.get('revision') != expected['revision']:
                raise ValueError(f'{identity}: consumer resolved a different public tag or commit')
        print('All five public dependency tags and revisions matched preflight; SwiftSoup is vendored and the mirror tag was synthetic.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'Candidate consumer failed: {error}', file=sys.stderr)
        sys.exit(1)
