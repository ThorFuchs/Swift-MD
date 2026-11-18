#!/usr/bin/env python3
"""Export committed SwiftMD sources as an adapter distribution package.

This creates no git repository, tag or remote. Local file dependencies are
permitted only for explicitly marked disposable tests; never publish those.
"""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PATHS = ['Adapters/SwiftMDBlocks/Sources', 'Adapters/SwiftMDBlocks/Tests',
         'Adapters/SwiftMDBlocks/README.md', 'Adapters/SwiftMDBlocks/MIRROR_README.md', 'Tools/SwiftMDCLI/Sources',
         'Tools/NodeDependencies/package.json', 'Tools/NodeDependencies/package-lock.json',
         'Scripts/run-linux-constrained.sh', 'Scripts/run-linux-supervised.py',
         'Scripts/run-linux-systemd.py', 'Scripts/systemd-worker-guard.py',
         'Documentation/PROCESS_ISOLATION.md',
         'ThirdPartyLicenses', 'LICENSE']

def git(*args):
    return subprocess.check_output(['git', '-C', str(ROOT), *args])

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', type=Path)
    parser.add_argument('--core-version', required=True)
    parser.add_argument('--gfm-version', required=True)
    parser.add_argument('--highlight-version', required=True)
    parser.add_argument('--core-url', default='https://github.com/ThorFuchs/Swift-MD.git')
    parser.add_argument('--gfm-url', default='https://github.com/ThorFuchs/Swift-GFM.git')
    parser.add_argument('--highlight-url', default='https://github.com/ThorFuchs/Swift-Highlight.git')
    parser.add_argument('--local-test', action='store_true')
    parser.add_argument('--include-locked-renderers', action='store_true',
                        help='fetch and verify pinned npm tarballs and bundle their renderer files')
    args = parser.parse_args()
    for version in (args.core_version, args.gfm_version, args.highlight_version):
        if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
            parser.error('versions must be stable numeric major.minor.patch versions')
    for url in (args.core_url, args.gfm_url, args.highlight_url):
        if not (url.startswith('https://') or (args.local_test and url.startswith('file:///'))):
            parser.error('dependencies require HTTPS; file URLs require --local-test')
    destination = args.destination.resolve()
    if destination.exists(): parser.error('destination already exists')
    if git('status', '--porcelain', '--untracked-files=all').strip():
        parser.error('source checkout must be clean, including untracked files')
    commit = git('rev-parse', 'HEAD').decode().strip()
    # Archive contains committed files only; no symlinks or traversal are accepted.
    archive = git('archive', '--format=tar', commit, '--', *PATHS)
    renderer_resources = {}
    loaded_resources = {}
    if args.include_locked_renderers:
        lock = json.loads((ROOT / 'Tools/NodeDependencies/package-lock.json').read_text())
        requested = {
            'katex': {'dist/katex.js': 'katex.cjs', 'LICENSE': 'KaTeX-LICENSE.txt'},
            'pele': {'dist/pele.js': 'pele.mjs', 'dist/pele.global.js': 'pele.global.js', 'LICENSE': 'Pele-LICENSE.txt'},
        }
        for package, files in requested.items():
            entry = lock['packages']['node_modules/' + package]
            url, integrity = entry['resolved'], entry['integrity']
            if not url.startswith('https://') or not integrity.startswith('sha512-'):
                raise ValueError(f'untrusted archive metadata for {package}')
            with urllib.request.urlopen(url, timeout=30) as response:
                content = response.read(10_000_001)
            if len(content) > 10_000_000 or hashlib.sha512(content).digest() != base64.b64decode(integrity[7:], validate=True):
                raise ValueError(f'archive integrity or size mismatch for {package}')
            found = {}
            with tarfile.open(fileobj=io.BytesIO(content), mode='r:gz') as tar:
                for source, target in files.items():
                    members = [m for m in tar.getmembers() if m.name == 'package/' + source]
                    if len(members) != 1 or not members[0].isfile() or members[0].size > 3_000_000:
                        raise ValueError(f'unsafe or missing archive member: {package}/{source}')
                    data = tar.extractfile(members[0]).read()
                    loaded_resources[target] = data
                    found[target] = hashlib.sha256(data).hexdigest()
            renderer_resources[package] = {'version': entry['version'], 'source': url,
                                           'archive_integrity': integrity, 'files_sha256': found}
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        members = tar.getmembers()
        if any(m.issym() or m.islnk() or m.name.startswith('/') or '..' in Path(m.name).parts for m in members):
            raise ValueError('unsafe archive member')
        destination.mkdir(parents=True, exist_ok=False)
        tar.extractall(destination, members=members)
    if loaded_resources:
        resources = destination / 'Adapters/SwiftMDBlocks/Sources/SwiftMDBundled/RendererAssets'
        resources.mkdir(parents=True)
        for name, data in loaded_resources.items():
            (resources / name).write_bytes(data)
    def q(value): return json.dumps(value, ensure_ascii=True)
    manifest = '''// swift-tools-version: 6.1
// Generated; edit SwiftMD instead. DO NOT EDIT THIS MIRROR.
import PackageDescription
let package = Package(
    name: "SwiftMDAdapters",
    platforms: [.macOS(.v15), .iOS(.v18), .tvOS(.v18), .watchOS(.v11), .visionOS(.v2)],
    products: [
        .library(name: "SwiftMDBlocks", targets: ["SwiftMDBlocks"]),
        .library(name: "SwiftMDHighlight", targets: ["SwiftMDHighlight"]),
        .library(name: "SwiftMDKaTeXNode", targets: ["SwiftMDKaTeXNode"]),
        .library(name: "SwiftMDPeleNode", targets: ["SwiftMDPeleNode"]),
        .library(name: "SwiftMDCompiler", targets: ["SwiftMDCompiler"]),
        .library(name: "SwiftMDJavaScriptCore", targets: ["SwiftMDJavaScriptCore"]),
        BUNDLED_PRODUCT
        .executable(name: "swift-md", targets: ["SwiftMDCLI"]),
    ],
    dependencies: [
        .package(url: CORE_URL, exact: CORE_VERSION),
        .package(url: GFM_URL, exact: GFM_VERSION),
        .package(url: HIGHLIGHT_URL, exact: HIGHLIGHT_VERSION),
        .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.11.3"),
        .package(url: "https://github.com/nicklockwood/LRUCache.git", exact: "1.3.0"),
        .package(url: "https://github.com/apple/swift-atomics.git", exact: "1.3.1"),
    ],
    targets: [
        .target(name: "SwiftMDBlocks", dependencies: [.product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftSoup", package: "SwiftSoup")], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDBlocks"),
        .target(name: "SwiftMDHighlight", dependencies: ["SwiftMDBlocks", .product(name: "SwiftHighlight", package: "Swift-Highlight"), .product(name: "SwiftHighlightHTML", package: "Swift-Highlight")], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDHighlight"),
        .target(name: "SwiftMDKaTeXNode", dependencies: ["SwiftMDBlocks"], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDKaTeXNode"),
        .target(name: "SwiftMDPeleNode", dependencies: ["SwiftMDBlocks", "SwiftMDKaTeXNode"], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDPeleNode"),
        .target(name: "SwiftMDCompiler", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", .product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftGFM", package: "Swift-GFM")], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDCompiler"),
        .target(name: "SwiftMDJavaScriptCore", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", .product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftGFM", package: "Swift-GFM")], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDJavaScriptCore"),
        BUNDLED_TARGET
        .executableTarget(name: "SwiftMDCLI", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", .product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftGFM", package: "Swift-GFM")], path: "Tools/SwiftMDCLI/Sources/SwiftMDCLI"),
        .testTarget(name: "SwiftMDBlocksTests", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", "SwiftMDCompiler", "SwiftMDJavaScriptCore", .product(name: "SwiftSoup", package: "SwiftSoup"), .product(name: "SwiftGFM", package: "Swift-GFM"), .product(name: "SwiftMD", package: "Swift-MD")], path: "Adapters/SwiftMDBlocks/Tests/SwiftMDBlocksTests"),
    ], swiftLanguageModes: [.v6]
)
'''
    values = {'CORE_URL':args.core_url, 'CORE_VERSION':args.core_version, 'GFM_URL':args.gfm_url,
              'GFM_VERSION':args.gfm_version, 'HIGHLIGHT_URL':args.highlight_url, 'HIGHLIGHT_VERSION':args.highlight_version}
    for key, value in values.items(): manifest = manifest.replace(key, q(value))
    manifest = manifest.replace('BUNDLED_PRODUCT', '.library(name: "SwiftMDBundled", targets: ["SwiftMDBundled"]),' if args.include_locked_renderers else '')
    manifest = manifest.replace('BUNDLED_TARGET', '''.target(name: "SwiftMDBundled", dependencies: ["SwiftMDBlocks", .target(name: "SwiftMDJavaScriptCore", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])), .target(name: "SwiftMDCompiler", condition: .when(platforms: [.linux]))], path: "Adapters/SwiftMDBlocks/Sources/SwiftMDBundled", resources: [.copy("RendererAssets")]),''' if args.include_locked_renderers else '')
    if args.local_test: manifest = manifest.replace('\n', '\n// LOCAL TEST ONLY — NEVER PUBLISH\n', 1)
    (destination / 'Package.swift').write_text(manifest)
    (destination / 'README.md').write_bytes((destination / 'Adapters/SwiftMDBlocks/MIRROR_README.md').read_bytes())
    (destination / 'MIRROR-ORIGIN.json').write_text(json.dumps({'source_commit':commit, 'local_test_only':args.local_test, 'dependencies':values, 'renderer_resources':renderer_resources}, indent=2) + '\n')
    print(f'Generated {destination} from {commit}; local test only: {args.local_test}')

if __name__ == '__main__':
    try: main()
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f'error: {error}', file=sys.stderr); sys.exit(1)
