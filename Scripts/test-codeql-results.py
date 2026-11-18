#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Verify the security gate cannot treat missing or failed scans as clean."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import runpy

CHECK = Path(__file__).with_name('check-codeql-results.py')
REQUIRED = runpy.run_path(str(CHECK))['REQUIRED']


class CodeQLGateTests(unittest.TestCase):
    def test_missing_invalid_findings_and_clean(self):
        with tempfile.TemporaryDirectory(prefix='swiftmd-sarif-gate-') as name:
            root = Path(name)
            def check():
                return subprocess.run([sys.executable, str(CHECK), str(root), 'python'], capture_output=True).returncode
            self.assertEqual(check(), 2)
            path = root / 'result.sarif'
            notices = [{'descriptor': {'id': 'py/diagnostics/successfully-extracted-files'},
                        'locations': [{'physicalLocation': {'artifactLocation': {'uri': path}}}]}
                       for path in REQUIRED['python']]
            run = {'tool': {'driver': {'name': 'CodeQL'}}, 'results': [],
                   'invocations': [{'executionSuccessful': True, 'toolExecutionNotifications': notices}]}
            data = {'version': '2.1.0', 'runs': [run]}
            path.write_text(json.dumps(data))
            self.assertEqual(check(), 0)
            removed = notices.pop()
            path.write_text(json.dumps(data))
            self.assertEqual(check(), 2)
            notices.append(removed)
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
