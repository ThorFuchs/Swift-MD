#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise a locally built, explicitly experimental math-aware CLI."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
CLI = Path(os.environ['SWIFTMD_CLI'])
NODE = os.environ['SWIFTMD_NODE']
KATEX = os.environ['SWIFTMD_KATEX']
PELE = os.environ['SWIFTMD_PELE']
OPTIONS = ['--highlight', '--katex-node', NODE, '--katex-module', KATEX,
           '--pele-node', NODE, '--pele-module', PELE, '--svg-prefix', 'math-cli']


class MathCLI(unittest.TestCase):
    def run_cli(self, *args, text=''):
        return subprocess.run([str(CLI), *args], input=text.encode(), capture_output=True)

    def test_complete_document(self):
        source = (r'Inline $x^2$ and code `$not_math$`.' + '\n\n'
                  '| A | B |\n| - | - |\n| x | [link](https://example.com) |\n\n'
                  '$$\n' + r'\frac{x}{2}' + '\n$$\n\n'
                  '```math\ny^2\n```\n\n```swift\nlet x = 1\n```\n\n'
                  '```mermaid\nflowchart LR\nA-->B\n```\n')
        result = self.run_cli(*OPTIONS, '--document', '--strict', text=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        html = result.stdout.decode()
        self.assertEqual(html.count('<math '), 3)
        self.assertEqual(html.count('display="block"'), 2)
        for marker in ('<table>', '$not_math$', 'hljs-keyword', '<svg', 'viewBox=', 'id="math-cli-2"'):
            self.assertIn(marker, html)
        self.assertNotIn('<script', html)
        self.assertEqual(result.stderr, b'')

    def test_failed_inline_math_fallback_and_strict_output(self):
        source = r'Broken $\badcommand{<script>}$ here.'
        result = self.run_cli(*OPTIONS, text=source)
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'&lt;script&gt;', result.stdout)
        self.assertNotIn(b'<script>', result.stdout)
        self.assertIn(b'[math]', result.stderr)
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'existing.html'
            output.write_text('unchanged')
            result = self.run_cli(*OPTIONS, '--strict', '--output', str(output), text=source)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, b'')
            self.assertEqual(output.read_text(), 'unchanged')

    def test_disabled_math_and_unclosed_display(self):
        source = 'Inline $x^2$.\n'
        result = self.run_cli(text=source)
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'$x^2$', result.stdout)
        self.assertNotIn(b'<math', result.stdout)
        result = self.run_cli(*OPTIONS, text='$$\nx^2\n')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b'')

    def test_explicit_experimental_version(self):
        result = self.run_cli('--version')
        self.assertEqual(result.returncode, 0)
        self.assertIn(b'experimental math parser (unreleased)', result.stdout)

    def test_unicode_currency_and_escapes(self):
        source = 'a $x$\u0301, \u2764\ufe0f$y$; Preis $5 und $10; \\$z\\$; `$q$`.'
        result = self.run_cli(*OPTIONS, text=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        html = result.stdout.decode()
        self.assertEqual(html.count('<math '), 2)
        self.assertIn('\u0301', html)
        self.assertIn('\u2764\ufe0f', html)
        self.assertIn('$5 und $10', html)
        self.assertIn('$z$', html)
        self.assertIn('$q$', html)

    def test_unsafe_html_is_explicitly_rejected_for_math_profile(self):
        result = self.run_cli(*OPTIONS, '--unsafe-html', text='Inline $x$.')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b'')


if __name__ == '__main__':
    unittest.main()
