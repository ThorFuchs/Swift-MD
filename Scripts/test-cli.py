#!/usr/bin/env python3
"""End-to-end tests against a built swift-md and real installed Node modules."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BINARY = Path(os.environ.get('SWIFTMD_CLI', ROOT / 'Tools/SwiftMDCLI/.build/debug/swift-md'))
NODE = os.environ.get('SWIFTMD_NODE', '/usr/bin/node')
KATEX = ROOT / 'Tools/NodeDependencies/node_modules/katex'
PELE = ROOT / 'Tools/NodeDependencies/node_modules/pele/dist/pele.js'
OPTIONS = ['--highlight', '--katex-node', NODE, '--katex-module', str(KATEX), '--pele-node', NODE, '--pele-module', str(PELE), '--svg-prefix', 'test-page']

class CLITests(unittest.TestCase):
    def run_cli(self, *args, source=''):
        return subprocess.run([str(BINARY), *args], input=source.encode(), capture_output=True)

    def test_stdin_stdout(self):
        result = self.run_cli(source='# Hello\n')
        self.assertEqual((result.returncode, result.stdout), (0, b'<h1>Hello</h1>\n'))

    def test_file_input_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            inp, out = Path(tmp)/'input.md', Path(tmp)/'output.html'
            inp.write_text('# File\n')
            result = self.run_cli('--document', '--output', str(out), str(inp))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('<h1>File</h1>', out.read_text())
            self.assertEqual(result.stdout, b'')

    def test_combined_renderers(self):
        source = '| a | b |\n| - | - |\n| x | [link](https://example.com) |\n\n```swift\nlet x = 1\n```\n\n```math\nx^2\n```\n\n```mermaid\nflowchart LR\nA-->B\n```\n'
        result = self.run_cli(*OPTIONS, '--document', source=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        for expected in [b'<table>', b'hljs-keyword', b'<math', b'<svg', b'viewBox=', b'id="test-page-2"']:
            self.assertIn(expected, result.stdout)
        self.assertNotIn(b'<script', result.stdout)
        self.assertEqual(result.stderr, b'')

    def test_strict_does_not_replace_file(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)/'existing.html'; out.write_text('unchanged')
            result = self.run_cli(*OPTIONS, '--strict', '--output', str(out), source='```math\n\\notACommand\n```\n')
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(out.read_text(), 'unchanged')
            self.assertEqual(result.stdout, b'')
            self.assertIn(b'block 0', result.stderr)

    def test_fallback(self):
        result = self.run_cli(*OPTIONS, source='```math\n\\notACommand{<bad>}\n```\n')
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'&lt;bad&gt;', result.stdout)
        self.assertIn(b'block 0', result.stderr)

    def test_argument_errors(self):
        for args in [('--pele-node', NODE), ('--katex-module', str(KATEX)), ('--bogus',), ('one', 'two')]:
            result = self.run_cli(*args)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b'')

    def test_version(self):
        result = self.run_cli('--version')
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'SwiftMD development;', result.stdout)
        pins = json.loads((ROOT / 'Tools/SwiftMDCLI/Package.resolved').read_text())['pins']
        gfm, = (pin['state'] for pin in pins if pin['identity'] == 'swift-gfm')
        self.assertIn(f"SwiftGFM {gfm['version']} ({gfm['revision']})".encode(), result.stdout)
        self.assertIn(b'27d942c8b0a62d192f616e5bf3578f4b6a89e180', result.stdout)

if __name__ == '__main__': unittest.main()
