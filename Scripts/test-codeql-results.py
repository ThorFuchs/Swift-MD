#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify the security gate cannot treat missing or failed scans as clean."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

CHECK = Path(__file__).with_name('check-codeql-results.py')


class CodeQLGateTests(unittest.TestCase):
    def test_missing_invalid_findings_and_clean(self):
        with tempfile.TemporaryDirectory(prefix='swiftmd-sarif-gate-') as name:
            root = Path(name)
            def check():
                return subprocess.run([sys.executable, str(CHECK), str(root)], capture_output=True).returncode
            self.assertEqual(check(), 2)
            path = root / 'result.sarif'
            run = {'tool': {'driver': {'name': 'CodeQL'}}, 'results': []}
            data = {'version': '2.1.0', 'runs': [run]}
            path.write_text(json.dumps(data))
            self.assertEqual(check(), 0)
            run['results'] = [{'ruleId': 'test/finding', 'locations': []}]
            path.write_text(json.dumps(data))
            self.assertEqual(check(), 1)
            run['results'] = []
            run['invocations'] = [{'executionSuccessful': False}]
            path.write_text(json.dumps(data))
            self.assertEqual(check(), 2)
            run['invocations'] = []
            run['tool']['driver']['name'] = 'other scanner'
            path.write_text(json.dumps(data))
            self.assertEqual(check(), 2)


if __name__ == '__main__':
    unittest.main()
