#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the Linux supervisor with real processes and actual renderers."""
from pathlib import Path
import json
import os
import signal
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SUPERVISOR = ROOT / 'Scripts/run-linux-supervised.py'
NODE = os.environ.get('SWIFTMD_NODE')
KATEX = os.environ.get('SWIFTMD_KATEX')
PELE = os.environ.get('SWIFTMD_PELE')
CLI = Path(os.environ.get('SWIFTMD_CLI', ROOT / 'Tools/SwiftMDCLI/.build/debug/swift-md'))


def command(program, *arguments, seconds=5, max_input=1_000_000, max_output=2_000_000, max_error=65_536):
    return [sys.executable, str(SUPERVISOR), '--seconds', str(seconds), '--memory-mib', '8192',
            '--file-mib', '2', '--input-bytes', str(max_input), '--output-bytes', str(max_output),
            '--error-bytes', str(max_error), '--', str(program), *arguments]


def run(program, *arguments, payload=b'', **limits):
    return subprocess.run(command(program, *arguments, **limits), input=payload, capture_output=True, timeout=15)


class LinuxSupervisor(unittest.TestCase):
    def test_empty_input_immediate_success(self):
        result = run('/bin/true')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'')

    def test_binary_stream_and_inherited_limits(self):
        code = ('import json,resource,sys; data=sys.stdin.buffer.read();'
                'sys.stderr.write(json.dumps([resource.getrlimit(resource.RLIMIT_AS)[0],'
                'resource.getrlimit(resource.RLIMIT_FSIZE)[0]]));sys.stdout.buffer.write(data)')
        result = run(sys.executable, '-c', code, payload=b'hello\x00\xff')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'hello\x00\xff')
        self.assertEqual(json.loads(result.stderr), [8192 * 1024 * 1024, 2 * 1024 * 1024])

    def test_input_limit_fails_without_output(self):
        result = run('/bin/cat', payload=b'x' * 101, max_input=100)
        self.assertEqual(result.returncode, 125)
        self.assertEqual(result.stdout, b'')
        self.assertIn(b'input limit exceeded', result.stderr)

    def test_exact_stream_limits_succeed(self):
        result = run('/bin/cat', payload=b'x' * 100, max_input=100, max_output=100)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'x' * 100)

    def test_stdout_limit_fails_without_partial_output(self):
        result = run(sys.executable, '-c', 'import os;os.write(1,b"x"*200000)', max_output=1000)
        self.assertEqual(result.returncode, 125)
        self.assertEqual(result.stdout, b'')
        self.assertIn(b'stdout limit exceeded', result.stderr)

    def test_stderr_limit_fails_without_output(self):
        result = run(sys.executable, '-c', 'import os;os.write(2,b"e"*200000)', max_error=1000)
        self.assertEqual(result.returncode, 125)
        self.assertEqual(result.stdout, b'')
        self.assertIn(b'stderr limit exceeded', result.stderr)

    def test_worker_error_suppresses_partial_stdout(self):
        code = 'import sys;sys.stdin.buffer.read();print("partial");sys.stderr.write("diagnostic");sys.exit(7)'
        result = run(sys.executable, '-c', code)
        self.assertEqual(result.returncode, 7)
        self.assertEqual(result.stdout, b'')
        self.assertEqual(result.stderr, b'diagnostic')

    def test_deadline_kills_worker_group_and_discards_partial_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            sentinel = Path(tmp) / 'survived'
            child = 'import pathlib,sys,time;time.sleep(2);pathlib.Path(sys.argv[1]).write_text("survived")'
            parent = ('import os,subprocess,sys,time;sys.stdin.buffer.read();os.write(1,b"partial");'
                      'subprocess.Popen([sys.executable,"-c",sys.argv[1],sys.argv[2]]);time.sleep(10)')
            result = run(sys.executable, '-c', parent, child, str(sentinel), seconds=1)
            self.assertEqual(result.returncode, 124, result.stderr)
            self.assertEqual(result.stdout, b'')
            time.sleep(2.2)
            self.assertFalse(sentinel.exists())

    def test_detached_child_remains_a_documented_boundary(self):
        with tempfile.TemporaryDirectory() as tmp:
            sentinel = Path(tmp) / 'detached'
            child = 'import pathlib,sys,time;time.sleep(2);pathlib.Path(sys.argv[1]).write_text("detached")'
            parent = ('import os,subprocess,sys,time;sys.stdin.buffer.read();'
                      'subprocess.Popen([sys.executable,"-c",sys.argv[1],sys.argv[2]],preexec_fn=os.setsid,'
                      'stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);time.sleep(10)')
            result = run(sys.executable, '-c', parent, child, str(sentinel), seconds=1)
            self.assertEqual(result.returncode, 124, result.stderr)
            time.sleep(2.2)
            self.assertTrue(sentinel.exists(), 'detached-child behavior changed; review the security contract')

    def test_deadline_includes_slow_stdin(self):
        process = subprocess.Popen(command('/bin/cat', seconds=1), stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            result = process.wait(timeout=5)
            self.assertEqual(result, 124)
            self.assertEqual(process.stdout.read(), b'')
            self.assertIn(b'deadline exceeded', process.stderr.read())
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            for stream in (process.stdin, process.stdout, process.stderr):
                stream.close()

    def test_deadline_includes_stalled_output_delivery(self):
        code = 'import os,sys;sys.stdin.buffer.read();os.write(1,b"x"*1000000)'
        process = subprocess.Popen(command(sys.executable, '-c', code, seconds=2),
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            process.stdin.close()
            self.assertEqual(process.wait(timeout=7), 124)
            self.assertIn(b'delivery deadline exceeded', process.stderr.read())
            # A pipe cannot provide transactional delivery after it starts.
            self.assertLess(len(process.stdout.read()), 1000000)
        finally:
            if process.poll() is None:
                process.kill()
                process.wait()
            process.stdout.close()
            process.stderr.close()

    def test_sigterm_cleans_up_worker_group(self):
        with tempfile.TemporaryDirectory() as tmp:
            ready = Path(tmp) / 'ready'
            sentinel = Path(tmp) / 'survived'
            code = ('import pathlib,sys,time;sys.stdin.buffer.read();'
                    'pathlib.Path(sys.argv[1]).write_text("ready");time.sleep(2);'
                    'pathlib.Path(sys.argv[2]).write_text("survived")')
            process = subprocess.Popen(command(sys.executable, '-c', code, str(ready), str(sentinel)),
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                process.stdin.close()
                for _ in range(40):
                    if ready.exists(): break
                    time.sleep(0.05)
                self.assertTrue(ready.exists(), 'worker did not start')
                process.send_signal(signal.SIGTERM)
                self.assertEqual(process.wait(timeout=5), 143)
                time.sleep(2.2)
                self.assertFalse(sentinel.exists())
            finally:
                if process.poll() is None:
                    process.kill()
                    process.wait()
                process.stdout.close()
                process.stderr.close()

    def test_real_cli_combines_three_renderers(self):
        for value in (NODE, KATEX, PELE):
            self.assertTrue(value and Path(value).is_absolute() and Path(value).exists(), 'real renderer paths are required')
        self.assertTrue(CLI.is_file(), 'build the real CLI before this test')
        source = (b'| A | B |\n| - | - |\n| x | y |\n\n```swift\nlet n = 1\n```\n\n'
                  b'```math\nx^2\n```\n\n```mermaid\nflowchart LR\nA-->B\n```\n')
        result = run(CLI, '--strict', '--document', '--highlight', '--katex-node', NODE,
                     '--katex-module', KATEX, '--pele-node', NODE, '--pele-module', PELE,
                     '--svg-prefix', 'supervised', payload=source, seconds=20)
        self.assertEqual(result.returncode, 0, result.stderr)
        for fragment in (b'<table>', b'hljs-keyword', b'<math', b'<svg', b'viewBox='):
            self.assertIn(fragment, result.stdout)

    def test_real_cli_strict_failure_emits_no_html(self):
        for value in (NODE, KATEX):
            self.assertTrue(value and Path(value).is_absolute() and Path(value).exists(), 'real renderer paths are required')
        result = run(CLI, '--strict', '--katex-node', NODE, '--katex-module', KATEX,
                     payload=b'```math\n\\badcommand{<script>}\n```\n', seconds=20)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b'')
        self.assertIn(b'block 0', result.stderr)


if __name__ == '__main__':
    unittest.main()
