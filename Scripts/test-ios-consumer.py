#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build and run a disposable SwiftMDBundled consumer on a booted iOS simulator."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def call(*args, capture=False, timeout=120):
    result = subprocess.run(args, check=True, text=True, timeout=timeout,
                            stdout=subprocess.PIPE if capture else None)
    return result.stdout if capture else ''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--simulator', help='UDID of an already booted iOS simulator')
    parser.add_argument('--core-version', default='0.1.0')
    args = parser.parse_args()
    if sys.platform != 'darwin' or not shutil.which('xcodegen') or not shutil.which('xcrun'):
        raise ValueError('macOS, Xcode and xcodegen are required')
    devices = json.loads(call('xcrun', 'simctl', 'list', 'devices', 'booted', '--json', capture=True))['devices']
    booted = [device for runtime, items in devices.items() if 'iOS' in runtime
              for device in items if device.get('state') == 'Booted' and device.get('isAvailable')]
    if args.simulator:
        booted = [device for device in booted if device['udid'] == args.simulator]
    if len(booted) != 1:
        raise ValueError('select exactly one already booted iOS simulator with --simulator')
    simulator = booted[0]['udid']
    pins = {p['identity']: p['state'] for p in json.loads(
        (ROOT / 'Adapters/SwiftMDBlocks/Package.resolved').read_text())['pins']}
    bundle = 'io.github.thorfuchs.swiftmd.probe.p' + uuid.uuid4().hex
    installed = False
    with tempfile.TemporaryDirectory(prefix='swiftmd-ios-consumer-') as name:
        temp = Path(name)
        mirror = temp / 'SwiftMDAdapters'
        try:
            call(sys.executable, str(ROOT / 'Scripts/generate-adapter-mirror.py'), str(mirror),
                 '--core-version', args.core_version, '--gfm-version', pins['swift-gfm']['version'],
                 '--highlight-version', pins['swift-highlight']['version'], '--local-test',
                 '--include-locked-renderers')
            project = temp / 'project.yml'
            project.write_text(f'''name: SwiftMDIntegratedProbe
options:
  deploymentTarget:
    iOS: "18.0"
packages:
  SwiftMDAdapters:
    path: {json.dumps(str(mirror))}
targets:
  SwiftMDIntegratedProbe:
    type: application
    platform: iOS
    sources:
      - path: {json.dumps(str(ROOT / 'Tests/IntegratedIOS/ProbeApp.swift'))}
    dependencies:
      - package: SwiftMDAdapters
        product: SwiftMDBundled
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {json.dumps(bundle)}
        GENERATE_INFOPLIST_FILE: YES
        SWIFT_VERSION: "6.0"
        TARGETED_DEVICE_FAMILY: "1,2"
''')
            call('xcodegen', 'generate', '--spec', str(project))
            log = temp / 'build.log'
            with log.open('w') as output:
                result = subprocess.run(['xcodebuild', '-project', str(temp / 'SwiftMDIntegratedProbe.xcodeproj'),
                                         '-scheme', 'SwiftMDIntegratedProbe', '-configuration', 'Debug',
                                         '-destination', f'platform=iOS Simulator,id={simulator}',
                                         '-derivedDataPath', str(temp / 'DerivedData'), 'build'],
                                        stdout=output, stderr=subprocess.STDOUT, text=True, timeout=600)
            if result.returncode:
                print('\n'.join(log.read_text(errors='replace').splitlines()[-35:]), file=sys.stderr)
                raise ValueError('iOS simulator build failed')
            app = temp / 'DerivedData/Build/Products/Debug-iphonesimulator/SwiftMDIntegratedProbe.app'
            call('xcrun', 'simctl', 'install', simulator, str(app))
            installed = True
            call('xcrun', 'simctl', 'launch', simulator, bundle)
            container = Path(call('xcrun', 'simctl', 'get_app_container', simulator, bundle, 'data', capture=True).strip())
            marker = container / 'Documents/swiftmd-probe-result.txt'
            deadline = time.monotonic() + 30
            while not marker.is_file() and time.monotonic() < deadline:
                time.sleep(0.2)
            if not marker.is_file():
                raise ValueError('simulator application did not produce a test result')
            result = marker.read_text(encoding='utf-8')
            print(result)
            if not result.startswith('PASS:'):
                raise ValueError('integrated iOS rendering failed')
            print('iOS simulator consumer passed with a generated local-only mirror; no Node or app-supplied scripts.')
        finally:
            if installed:
                subprocess.run(['xcrun', 'simctl', 'uninstall', simulator, bundle],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as error:
        print(f'iOS consumer test failed: {error}', file=sys.stderr)
        sys.exit(1)
