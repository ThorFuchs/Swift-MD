#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the vendor audit against accidental changes and added fixtures."""
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('vendor_audit', ROOT / 'Scripts/audit-vendored-swiftsoup.py')
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


class VendorAuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='swiftmd-vendor-audit-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.vendor = self.root / 'Adapters/SwiftMDBlocks/Vendor/SwiftSoup'
        self.vendor.parent.mkdir(parents=True)
        shutil.copytree(ROOT / 'Adapters/SwiftMDBlocks/Vendor/SwiftSoup', self.vendor)
        shutil.copytree(ROOT / 'ThirdPartyLicenses', self.root / 'ThirdPartyLicenses')
        self.addCleanup(patch.stopall)
        patch.object(audit, 'ROOT', self.root).start()
        patch.object(audit, 'VENDOR', self.vendor).start()

    def test_unchanged_snapshot_passes(self):
        audit.audit()

    def test_modified_source_is_rejected(self):
        with (self.vendor / 'Sources/SwiftSoup.swift').open('ab') as stream:
            stream.write(b'\n// altered\n')
        with self.assertRaisesRegex(ValueError, 'vendored file changed'):
            audit.audit()

    def test_extra_fixture_is_rejected(self):
        fixture = self.vendor / 'Tests/corpus/page.html'
        fixture.parent.mkdir(parents=True)
        fixture.write_text('<p>fixture</p>')
        with self.assertRaisesRegex(ValueError, 'unexpected or missing vendor files'):
            audit.audit()

    def test_changed_jsoup_notice_is_rejected(self):
        (self.vendor / 'JSOUP-LICENSE.txt').write_text('changed')
        with self.assertRaisesRegex(ValueError, 'jsoup reference license differs'):
            audit.audit()

    def test_symlink_is_rejected(self):
        source = self.vendor / 'Sources/SwiftSoup.swift'
        source.unlink()
        source.symlink_to(self.vendor / 'LICENSE')
        with self.assertRaisesRegex(ValueError, 'symbolic link'):
            audit.audit()


if __name__ == '__main__':
    unittest.main()
