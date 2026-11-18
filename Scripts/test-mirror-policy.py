#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Check the mirror generator's local-only and public verification boundaries."""
import json
import importlib.util
import io
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
GENERATOR = ROOT / 'Scripts/generate-adapter-mirror.py'
SPEC = importlib.util.spec_from_file_location('swiftmd_mirror_generator', GENERATOR)
generator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(generator)


class MirrorPolicyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='swiftmd-mirror-policy-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def run_generator(self, destination, *flags):
        env = os.environ.copy()
        index = int(env.get('GIT_CONFIG_COUNT', '0'))
        for path in (ROOT, ROOT / '.git'):
            env[f'GIT_CONFIG_KEY_{index}'] = 'safe.directory'
            env[f'GIT_CONFIG_VALUE_{index}'] = str(path)
            index += 1
        env['GIT_CONFIG_COUNT'] = str(index)
        return subprocess.run([sys.executable, str(GENERATOR), str(destination),
                               '--core-version', '0.1.0', '--gfm-version', '1.0.1',
                               '--highlight-version', '1.0.1', *flags],
                              capture_output=True, text=True, env=env, timeout=30)

    def test_mode_must_be_explicit_and_unambiguous(self):
        for flags in ((), ('--local-test', '--verify-public-dependencies')):
            dest = self.root / ('mirror-' + str(len(flags)))
            result = self.run_generator(dest, *flags)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('choose exactly one', result.stderr)
            self.assertFalse(dest.exists())

    def test_local_mirror_is_marked_and_existing_destination_is_preserved(self):
        dest = self.root / 'mirror'
        result = self.run_generator(dest, '--local-test', '--core-url', 'file:///tmp/local-only.git')
        self.assertEqual(result.returncode, 0, result.stderr)
        origin = json.loads((dest / 'MIRROR-ORIGIN.json').read_text())
        self.assertTrue(origin['local_test_only'])
        self.assertTrue(origin['release_review_required'])
        self.assertIn('LOCAL TEST ONLY', (dest / 'Package.swift').read_text())
        sentinel = dest / 'sentinel'
        sentinel.write_text('keep')
        result = self.run_generator(dest, '--local-test')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(sentinel.read_text(), 'keep')

    def test_public_mode_rejects_noncanonical_sources_before_fetch(self):
        for url in ('file:///tmp/local-only.git', 'https://example.invalid/Swift-MD.git'):
            dest = self.root / ('mirror-file' if url.startswith('file:') else 'mirror-https')
            result = self.run_generator(dest, '--verify-public-dependencies', '--core-url', url)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(dest.exists())

    def test_public_preflight_rejects_wrong_tag_and_unadvertised_source(self):
        pins = {p['identity']: p['state']['revision'] for p in
                json.loads((ROOT / 'Adapters/SwiftMDBlocks/Package.resolved').read_text())['pins']}
        revisions = {
            'https://github.com/ThorFuchs/Swift-MD.git': 'f' * 40,
            'https://github.com/ThorFuchs/Swift-GFM.git': pins['swift-gfm'],
            'https://github.com/ThorFuchs/Swift-Highlight.git': pins['swift-highlight'],
            'https://github.com/scinfu/SwiftSoup.git': pins['swiftsoup'],
            'https://github.com/nicklockwood/LRUCache.git': pins['lrucache'],
            'https://github.com/apple/swift-atomics.git': pins['swift-atomics'],
        }
        args = SimpleNamespace(core_url='https://github.com/ThorFuchs/Swift-MD.git',
                               gfm_url='https://github.com/ThorFuchs/Swift-GFM.git',
                               highlight_url='https://github.com/ThorFuchs/Swift-Highlight.git',
                               core_version='0.1.0', gfm_version='1.0.1', highlight_version='1.0.1')
        head = subprocess.check_output(['git', '-c', f'safe.directory={ROOT}', '-C', str(ROOT),
                                        'rev-parse', 'HEAD'], text=True).strip()
        with patch.object(generator, 'public_tag', side_effect=lambda url, version: revisions[url]), \
             patch.object(generator, 'public_refs', return_value={'refs/heads/other': '0' * 40}):
            with self.assertRaisesRegex(ValueError, 'source commit is not an advertised'):
                generator.verify_public_dependencies(args, head)
        revisions[args.gfm_url] = '0' * 40
        with patch.object(generator, 'public_tag', side_effect=lambda url, version: revisions[url]):
            with self.assertRaisesRegex(ValueError, 'public tag differs'):
                generator.verify_public_dependencies(args, head)

    def test_corrupt_renderer_archive_does_not_create_destination(self):
        dest = self.root / 'corrupt-mirror'
        argv = [str(GENERATOR), str(dest), '--core-version', '0.1.0', '--gfm-version', '1.0.1',
                '--highlight-version', '1.0.1', '--local-test', '--include-locked-renderers']
        with patch.object(sys, 'argv', argv), \
             patch.object(generator, 'git', side_effect=[b'', b'0' * 40, b'']), \
             patch.object(generator.urllib.request, 'urlopen', return_value=io.BytesIO(b'corrupt archive')):
            with self.assertRaisesRegex(ValueError, 'archive integrity or size mismatch'):
                generator.main()
        self.assertFalse(dest.exists())


if __name__ == '__main__':
    unittest.main()
