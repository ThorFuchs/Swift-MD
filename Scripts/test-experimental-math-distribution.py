#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Test the bundled math prototype with disposable local Git tags only."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
GFM_URL = 'https://github.com/ThorFuchs/Swift-GFM.git'


def run(*args, cwd=None, capture=False):
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None).stdout


def main():
    gfm_source = Path(os.environ['SWIFTMD_EXPERIMENTAL_GFM_SOURCE']).resolve()
    node = Path(os.environ['SWIFTMD_NODE'])
    if not node.is_absolute() or not node.is_file():
        raise ValueError('SWIFTMD_NODE must name an existing absolute executable')
    if run('git', 'status', '--porcelain', '--untracked-files=all', cwd=ROOT, capture=True).strip():
        raise ValueError('SwiftMD checkout must be clean')
    if run('git', 'status', '--porcelain', '--untracked-files=all', cwd=gfm_source, capture=True).strip():
        raise ValueError('SwiftGFM test checkout must be clean')
    source_revision = run('git', 'rev-parse', 'HEAD', cwd=ROOT, capture=True).strip()
    gfm_revision = run('git', 'rev-parse', 'HEAD', cwd=gfm_source, capture=True).strip()
    info = json.loads((ROOT / 'Adapters/SwiftMDBlocks/SwiftHTML-PROVENANCE.json').read_text())
    with tempfile.TemporaryDirectory(prefix='swiftmd-experimental-math-consumer-') as name:
        temp = Path(name)
        core, gfm, mirror, consumer = (temp / part for part in
                                       ('Swift-MD.git', 'Swift-GFM.git', 'SwiftMDAdapters', 'Consumer'))
        run('git', 'clone', '--quiet', '--bare', '--no-hardlinks', str(ROOT), str(core))
        run('git', '-C', str(core), 'update-ref', '-d', 'refs/tags/1.0.0')
        run('git', '-C', str(core), 'tag', '1.0.0', source_revision)
        run('git', 'clone', '--quiet', '--bare', '--no-hardlinks', str(gfm_source), str(gfm))
        run('git', '-C', str(gfm), 'update-ref', '-d', 'refs/tags/1.0.1')
        run('git', '-C', str(gfm), 'tag', '1.0.1', gfm_revision)
        # All test tags above are confined to temporary bare repositories.
        run(sys.executable, str(ROOT / 'Scripts/generate-adapter-mirror.py'), str(mirror),
            '--core-version', '1.0.0', '--gfm-version', '1.0.1', '--highlight-version', '1.0.1',
            '--core-url', core.as_uri(), '--swifthtml-url', info['public_repository'],
            '--swifthtml-version', info['public_version'], '--local-test', '--include-locked-renderers')
        origin = json.loads((mirror / 'MIRROR-ORIGIN.json').read_text())
        if origin['source_commit'] != source_revision or not origin['local_test_only']:
            raise ValueError('temporary mirror provenance does not match')
        run('git', 'init', '--quiet', cwd=mirror)
        run('git', 'add', '.', cwd=mirror)
        run('git', '-c', 'user.name=SwiftMD test', '-c', 'user.email=invalid@example.invalid',
            'commit', '--quiet', '-m', 'Disposable mirror', cwd=mirror)
        run('git', 'tag', '1.0.0', cwd=mirror)
        (consumer / 'Sources/Consumer').mkdir(parents=True)
        (consumer / 'Package.swift').write_text(f'''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "Consumer", platforms: [.macOS(.v15)], dependencies: [
    .package(url: {json.dumps(core.as_uri())}, exact: "1.0.0"),
    .package(url: {json.dumps(mirror.as_uri())}, exact: "1.0.0")
], targets: [.executableTarget(name: "Consumer", dependencies: [
    .product(name: "SwiftMDBundled", package: "SwiftMDAdapters")])])
''', encoding='utf-8')
        (consumer / 'Sources/Consumer/main.swift').write_text(r'''import Foundation
import SwiftMDBundled
let input = #"""
Inline $x^2$ and broken $\badcommand{<script>}$.

$$
\frac{x}{2}
$$

```math
y^2
```

```swift
let x = 1
```

```mermaid
flowchart LR
A-->B
```
"""#
let result = try SwiftMDIntegrated.render(input, svgPrefix: "bundled-math", nodeExecutable: ProcessInfo.processInfo.environment["SWIFTMD_NODE"]!)
precondition(result.diagnostics.count == 1)
precondition(result.html.components(separatedBy: "<math ").count - 1 == 3)
precondition(result.html.contains("display=\"block\"") && result.html.contains("hljs-keyword"))
precondition(result.html.contains("<svg") && result.html.contains("viewBox="))
precondition(result.html.contains("&lt;script&gt;") && !result.html.contains("<script>"))
print("Experimental bundled Markdown math consumer OK")
''', encoding='utf-8')
        run('swift', 'package', '--package-path', str(consumer), 'config', 'set-mirror',
            '--original', GFM_URL, '--mirror', gfm.as_uri())
        run('swift', 'run', '--package-path', str(consumer), '-j', '4',
            '-Xswiftc', '-DSWIFTMD_EXPERIMENTAL_GFM_MATH', 'Consumer')
        pins = {pin['identity']: pin['state'] for pin in json.loads((consumer / 'Package.resolved').read_text())['pins']}
        if pins['swift-gfm']['revision'] != gfm_revision or pins['swift-html']['revision'] != info['tested_revision']:
            raise ValueError('consumer resolved unexpected SwiftGFM or SwiftHTML commits')
        print(f'Local-only bundled math gate passed: SwiftMD {source_revision}, SwiftGFM {gfm_revision}; '
              'test tags are synthetic, SwiftHTML uses its public release.')


if __name__ == '__main__':
    try:
        main()
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Experimental math distribution test failed: {error}', file=sys.stderr)
        sys.exit(1)
