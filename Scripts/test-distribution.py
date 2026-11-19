#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Test version-based consumers using disposable, explicitly synthetic tags."""
import json
import hashlib
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
TEST_VERSION = '1.0.0'  # Synthetic; only in disposable local repositories, never publish.


def call(*args, cwd=None, capture=False):
    # A container may run as a different UID from the explicitly selected
    # workspace (e.g. actions/checkout). Trust only this exact source path for
    # these subprocesses, without persisting global Git configuration. Preserve
    # any command-scoped Git configuration already supplied by the caller.
    env = os.environ.copy()
    index = int(env.get('GIT_CONFIG_COUNT', '0'))
    # Local clone invokes git-upload-pack on the checkout's .git directory.
    for path in (ROOT, ROOT / '.git'):
        env[f'GIT_CONFIG_KEY_{index}'] = 'safe.directory'
        env[f'GIT_CONFIG_VALUE_{index}'] = str(path)
        index += 1
    env['GIT_CONFIG_COUNT'] = str(index)
    return subprocess.run(args, cwd=cwd, check=True, text=True,
                          stdout=subprocess.PIPE if capture else None, env=env).stdout


def pin(identity):
    resolved = json.loads((ROOT / 'Adapters/SwiftMDBlocks/Package.resolved').read_text())
    matches = [pin for pin in resolved['pins'] if pin['identity'] == identity]
    if len(matches) != 1 or 'version' not in matches[0]['state']:
        raise ValueError(f'{identity} must have a resolved stable version')
    return matches[0]['state']


def write(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding='utf-8')


def main():
    if call('git', 'status', '--porcelain', '--untracked-files=all', cwd=ROOT, capture=True).strip():
        raise ValueError('source checkout must be clean, including untracked files')
    for key in ('SWIFTMD_NODE',):
        value = os.environ.get(key, '')
        if not value or not Path(value).is_absolute() or not Path(value).exists():
            raise ValueError(f'{key} must name an existing absolute path')
    source_commit = call('git', 'rev-parse', 'HEAD', cwd=ROOT, capture=True).strip()
    with tempfile.TemporaryDirectory(prefix='swiftmd-distribution-') as name:
        temp = Path(name)
        core = temp / 'Swift-MD.git'
        source = temp / 'source'
        mirror = temp / 'SwiftMDAdapters'
        call('git', 'clone', '--quiet', '--bare', '--no-hardlinks', str(ROOT), str(core))
        call('git', 'tag', TEST_VERSION, source_commit, cwd=core)
        call('git', 'clone', '--quiet', '--no-hardlinks', str(ROOT), str(source))
        call('git', 'checkout', '--quiet', '--detach', source_commit, cwd=source)
        core_url = core.as_uri()
        # Use the actual released dependencies; only SwiftMD and mirror tags are synthetic.
        call(sys.executable, str(source / 'Scripts/generate-adapter-mirror.py'), str(mirror),
             '--core-version', TEST_VERSION, '--gfm-version', pin('swift-gfm')['version'],
             '--highlight-version', pin('swift-highlight')['version'], '--core-url', core_url,
             '--local-test', '--include-locked-renderers')
        origin = json.loads((mirror / 'MIRROR-ORIGIN.json').read_text())
        if origin['source_commit'] != source_commit or origin['local_test_only'] is not True:
            raise ValueError('generated mirror provenance or local-test marker mismatch')
        if set(origin['renderer_resources']) != {'katex', 'pele'}:
            raise ValueError('generated mirror omitted pinned renderer provenance')
        original_vendor = source / 'Adapters/SwiftMDBlocks/Vendor/SwiftSoup'
        mirrored_vendor = mirror / 'Adapters/SwiftMDBlocks/Vendor/SwiftSoup'
        original_files = {p.relative_to(original_vendor) for p in original_vendor.rglob('*') if p.is_file()}
        mirrored_files = {p.relative_to(mirrored_vendor) for p in mirrored_vendor.rglob('*') if p.is_file()}
        if original_files != mirrored_files or any((original_vendor / p).read_bytes() !=
                                                   (mirrored_vendor / p).read_bytes() for p in original_files):
            raise ValueError('mirror vendor snapshot differs from the committed source')
        assets = mirror / 'Adapters/SwiftMDBlocks/Sources/SwiftMDBundled/RendererAssets'
        for package in ('katex', 'pele'):
            for filename, digest in origin['renderer_resources'][package]['files_sha256'].items():
                if hashlib.sha256((assets / filename).read_bytes()).hexdigest() != digest:
                    raise ValueError(f'generated renderer resource hash mismatch: {filename}')
        for resource, original in (
            ('KaTeX-THIRD-PARTY.md', 'KaTeX-THIRD-PARTY.md'),
            ('KaTeX-SIL-OFL-1.1.txt', 'KaTeX-SIL-OFL-1.1.txt'),
            ('Apache-2.0.txt', 'SwiftGFM-Apache-2.0.txt'),
            ('KaTeX-LICENSE.txt', 'KaTeX-MIT.txt'),
            ('Pele-LICENSE.txt', 'Pele-MIT.txt'),
            ('Pele-THIRD-PARTY.md', 'Pele-THIRD-PARTY.md'),
            ('Pele-esbuild-MIT.txt', 'Pele-esbuild-MIT.txt'),
            ('Pele-Mermaid-MIT.txt', 'Pele-Mermaid-MIT.txt'),
            ('Pele-d3-time-ISC.txt', 'Pele-d3-time-ISC.txt'),
            ('Pele-d3-time-format-and-scale-ISC.txt', 'Pele-d3-time-format-and-scale-ISC.txt'),
        ):
            if (assets / resource).read_bytes() != (source / 'ThirdPartyLicenses' / original).read_bytes():
                raise ValueError(f'generated renderer notice mismatch: {resource}')
        for relative in ('Scripts/run-linux-constrained.sh', 'Scripts/run-linux-supervised.py',
                         'Scripts/run-linux-systemd.py', 'Scripts/systemd-worker-guard.py',
                         'Documentation/PROCESS_ISOLATION.md', 'Documentation/SECURITY_CONTRACT.md'):
            if (mirror / relative).read_bytes() != (source / relative).read_bytes():
                raise ValueError(f'generated mirror omitted or changed isolation file: {relative}')
        call('git', 'init', '--quiet', cwd=mirror)
        call('git', 'add', '.', cwd=mirror)
        call('git', '-c', 'user.name=SwiftMD distribution test', '-c', 'user.email=invalid@example.invalid',
             'commit', '--quiet', '-m', 'Disposable distribution test', cwd=mirror)
        call('git', 'tag', TEST_VERSION, cwd=mirror)

        core_consumer = temp / 'CoreConsumer'
        write(core_consumer / 'Package.swift', f'''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "CoreConsumer", dependencies: [
    .package(url: {json.dumps(core_url)}, exact: "{TEST_VERSION}")
], targets: [.executableTarget(name: "CoreConsumer", dependencies: [
    .product(name: "SwiftMD", package: "Swift-MD")])])
''')
        write(core_consumer / 'Sources/CoreConsumer/main.swift', '''import SwiftMD
let result = try MarkdownCompiler().render("# SwiftMD\\n")
precondition(result.html == "<h1>SwiftMD</h1>\\n" && result.diagnostics.isEmpty)
print("Core versioned consumer OK")
''')
        call('swift', 'run', '--package-path', str(core_consumer), '-j', '4', 'CoreConsumer')
        core_pins = {p['identity']: p['state'] for p in
                     json.loads((core_consumer / 'Package.resolved').read_text())['pins']}
        if set(core_pins) != {'swift-md', 'swift-gfm'} or core_pins['swift-md']['revision'] != source_commit:
            raise ValueError('Core consumer resolved unexpected dependencies or source commit')
        if core_pins['swift-gfm'] != pin('swift-gfm'):
            raise ValueError('Core consumer resolved a different SwiftGFM tag or commit')

        consumer = temp / 'AdapterConsumer'
        write(consumer / 'Package.swift', f'''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "AdapterConsumer", platforms: [.macOS(.v15)], dependencies: [
    .package(url: {json.dumps(core_url)}, exact: "{TEST_VERSION}"),
    .package(url: {json.dumps(mirror.as_uri())}, exact: "{TEST_VERSION}")
], targets: [.executableTarget(name: "AdapterConsumer", dependencies: [
    .product(name: "SwiftMD", package: "Swift-MD"),
    .product(name: "SwiftMDBundled", package: "SwiftMDAdapters")])])
''')
        write(consumer / 'Sources/AdapterConsumer/main.swift', '''import Foundation
import SwiftMDBundled
let env = ProcessInfo.processInfo.environment
let input = "```swift\\nlet x = 1\\n```\\n\\n```math\\nx^2\\n```\\n\\n```mermaid\\nflowchart LR\\nA-->B\\n```\\n"
let result = try SwiftMDIntegrated.render(input, svgPrefix: "consumer", nodeExecutable: env["SWIFTMD_NODE"]!)
precondition(result.diagnostics.isEmpty && result.html.contains("hljs-keyword") &&
             result.html.contains("<math") && result.html.contains("<svg"))
precondition(!result.html.contains("<script"))
let reusable = try SwiftMDIntegrated(svgPrefix: "consumer-reuse", nodeExecutable: env["SWIFTMD_NODE"]!)
let first = try reusable.render(input)
let second = try reusable.render(input)
precondition(first.diagnostics.isEmpty && first.html == second.html && first.html.contains("consumer-reuse-2"))
let failed = try SwiftMDIntegrated.render("```math\\n\\\\badcommand{<script>}\\n```\\n", svgPrefix: "consumer-bad", nodeExecutable: env["SWIFTMD_NODE"]!)
precondition(failed.diagnostics.count == 1 && failed.html.contains("&lt;script&gt;") && !failed.html.contains("<script>"))
print("Adapter versioned consumer: all three real renderers OK")
''')
        call('swift', 'run', '--package-path', str(consumer), '-j', '4', 'AdapterConsumer')
        resolved = json.loads((consumer / 'Package.resolved').read_text())
        pins = {p['identity']: p['state'] for p in resolved['pins']}
        for identity in ('swift-gfm', 'swift-highlight'):
            if pins[identity] != pin(identity):
                raise ValueError(f'{identity} consumer tag or commit changed')
        if pins['swift-md']['revision'] != source_commit:
            raise ValueError('Adapter consumer resolved a different SwiftMD source commit')
        if 'swiftsoup' in pins or any(p.name.lower() == 'swiftsoup' for p in (consumer / '.build/checkouts').iterdir()):
            raise ValueError('adapter consumer unexpectedly fetched the external SwiftSoup package')
        for name in ('LICENSE', 'JSOUP-LICENSE.txt'):
            resources = [p for p in (consumer / '.build').rglob(name)
                         if 'checkouts' not in p.parts and ('resources' in str(p).lower() or '.bundle' in str(p))]
            if not any(p.read_bytes() == (original_vendor / name).read_bytes() for p in resources):
                raise ValueError(f'vendored SwiftSoup notice missing from built package resources: {name}')
        # An application may deliberately depend on the original SwiftSoup as
        # well. Its module must coexist with the vendored SwiftMDSoup module.
        coexist = temp / 'CoexistConsumer'
        write(coexist / 'Package.swift', f'''// swift-tools-version: 6.1
import PackageDescription
let package = Package(name: "CoexistConsumer", platforms: [.macOS(.v15)], dependencies: [
    .package(url: {json.dumps(mirror.as_uri())}, exact: "{TEST_VERSION}"),
    .package(url: "https://github.com/scinfu/SwiftSoup.git", exact: "2.11.3")
], targets: [.executableTarget(name: "CoexistConsumer", dependencies: [
    .product(name: "SwiftMDBundled", package: "SwiftMDAdapters"),
    .product(name: "SwiftSoup", package: "SwiftSoup")])])
''')
        write(coexist / 'Sources/CoexistConsumer/main.swift', '''import Foundation
import SwiftMDBundled
import SwiftSoup
let doc = try SwiftSoup.parse("<p>independent</p>")
let text = try doc.select("p").text()
precondition(text == "independent")
let result = try SwiftMDIntegrated.render("```math\\nx^2\\n```\\n", svgPrefix: "coexist", nodeExecutable: ProcessInfo.processInfo.environment["SWIFTMD_NODE"]!)
precondition(result.diagnostics.isEmpty && result.html.contains("<math"))
print("Vendored and external SwiftSoup modules coexist")
''')
        call('swift', 'run', '--package-path', str(coexist), '-j', '4', 'CoexistConsumer')
        print(f'Consumer gate passed for commit {source_commit}; SwiftMD/mirror tags are synthetic and local only.')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        print(f'Distribution gate failed: {error}', file=sys.stderr)
        sys.exit(1)
