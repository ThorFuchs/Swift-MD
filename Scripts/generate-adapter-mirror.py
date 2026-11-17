#!/usr/bin/env python3
"""Export committed SwiftMD sources as an adapter distribution package.

This creates no git repository, tag or remote. Local file dependencies are
permitted only for explicitly marked disposable tests; never publish those.
"""
import argparse
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
PATHS = ['Adapters/SwiftMDBlocks/Sources', 'Adapters/SwiftMDBlocks/Tests',
         'Adapters/SwiftMDBlocks/README.md', 'Tools/SwiftMDCLI/Sources',
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
    with tarfile.open(fileobj=io.BytesIO(archive)) as tar:
        members = tar.getmembers()
        if any(m.issym() or m.islnk() or m.name.startswith('/') or '..' in Path(m.name).parts for m in members):
            raise ValueError('unsafe archive member')
        destination.mkdir(parents=True, exist_ok=False)
        tar.extractall(destination, members=members)
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
        .executableTarget(name: "SwiftMDCLI", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", .product(name: "SwiftMD", package: "Swift-MD"), .product(name: "SwiftGFM", package: "Swift-GFM")], path: "Tools/SwiftMDCLI/Sources/SwiftMDCLI"),
        .testTarget(name: "SwiftMDBlocksTests", dependencies: ["SwiftMDBlocks", "SwiftMDHighlight", "SwiftMDKaTeXNode", "SwiftMDPeleNode", .product(name: "SwiftSoup", package: "SwiftSoup"), .product(name: "SwiftGFM", package: "Swift-GFM"), .product(name: "SwiftMD", package: "Swift-MD")], path: "Adapters/SwiftMDBlocks/Tests/SwiftMDBlocksTests"),
    ], swiftLanguageModes: [.v6]
)
'''
    values = {'CORE_URL':args.core_url, 'CORE_VERSION':args.core_version, 'GFM_URL':args.gfm_url,
              'GFM_VERSION':args.gfm_version, 'HIGHLIGHT_URL':args.highlight_url, 'HIGHLIGHT_VERSION':args.highlight_version}
    for key, value in values.items(): manifest = manifest.replace(key, q(value))
    if args.local_test: manifest = manifest.replace('\n', '\n// LOCAL TEST ONLY — NEVER PUBLISH\n', 1)
    (destination / 'Package.swift').write_text(manifest)
    (destination / 'MIRROR-ORIGIN.json').write_text(json.dumps({'source_commit':commit, 'local_test_only':args.local_test, 'dependencies':values}, indent=2) + '\n')
    print(f'Generated {destination} from {commit}; local test only: {args.local_test}')

if __name__ == '__main__':
    try: main()
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f'error: {error}', file=sys.stderr); sys.exit(1)
