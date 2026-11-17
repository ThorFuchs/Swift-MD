#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise the installed systemd worker with real and adversarial programs."""
import base64
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import time
import unittest

INSTALL = Path(os.environ.get('SWIFTMD_SYSTEMD_TEST_ROOT', '/opt/swiftmd-isolation-test'))
LAUNCHER = INSTALL / 'run-linux-systemd.py'
CLI = INSTALL / 'swift-md'
NODE = INSTALL / 'node'
KATEX = INSTALL / 'node_modules/katex'
PELE = INSTALL / 'node_modules/pele/dist/pele.js'


def command(*worker, seconds=15, output=2_000_000, file_mib=8):
    return ['/usr/bin/python3', '-I', str(LAUNCHER), '--seconds', str(seconds), '--memory-mib', '1024',
            '--tasks', '128', '--tmp-mib', '32', '--file-mib', str(file_mib),
            '--output-bytes', str(output), '--', *map(str, worker)]


def run(*worker, payload=b'', **options):
    return subprocess.run(command(*worker, **options), input=payload, capture_output=True, timeout=45)


class SystemdWorker(unittest.TestCase):
    def test_guard_rejects_unisolated_root_before_exec(self):
        with tempfile.TemporaryDirectory() as tmp:
            marker = Path(tmp) / 'executed'
            encoded = base64.b64encode(json.dumps(['/usr/bin/touch', str(marker)]).encode()).decode()
            result = subprocess.run(['/usr/bin/python3', '-I', str(INSTALL / 'systemd-worker-guard.py'),
                                     '--unit', 'test.service', '--memory-bytes', '1024', '--tasks', '16',
                                     '--file-bytes', '1024', '--tmp-bytes', '1024', '--command', encoded],
                                    capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 125)
            self.assertIn(b'must not run as root', result.stderr)
            self.assertFalse(marker.exists())

    def test_three_real_renderers_and_strict_fallback(self):
        for path in (LAUNCHER, CLI, NODE, KATEX, PELE):
            self.assertTrue(path.exists(), f'missing installed test dependency {path}')
        source = (b'| A | B |\n| - | - |\n| x | y |\n\n```swift\nlet n = 1\n```\n\n'
                  b'```math\nx^2\n```\n\n```mermaid\nflowchart LR\nA-->B\n```\n')
        options = ('--strict', '--document', '--highlight', '--katex-node', NODE,
                   '--katex-module', KATEX, '--pele-node', NODE, '--pele-module', PELE,
                   '--svg-prefix', 'systemd')
        result = run(CLI, *options, payload=source)
        self.assertEqual(result.returncode, 0, result.stderr)
        for marker in (b'<table>', b'hljs-keyword', b'<math', b'<svg', b'viewBox='):
            self.assertIn(marker, result.stdout)
        failed = run(CLI, *options, payload=b'```math\n\\badcommand{<script>}\n```\n')
        self.assertNotEqual(failed.returncode, 0)
        self.assertEqual(failed.stdout, b'')
        self.assertIn(b'block 0', failed.stderr)

    def test_arguments_are_data_and_output_is_bounded(self):
        code = 'import sys;sys.stdin.buffer.read();sys.stdout.write(sys.argv[1])'
        result = run('/usr/bin/python3', '-c', code, '100% literal')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'100% literal')
        flood = run('/usr/bin/python3', '-c', 'import os,sys;sys.stdin.buffer.read();os.write(1,b"x"*200000)', output=1000)
        self.assertNotEqual(flood.returncode, 0)
        self.assertEqual(flood.stdout, b'')
        self.assertIn(b'stdout limit exceeded', flood.stderr)

    def test_cgroup_stops_detached_descendant(self):
        code = '''import os,sys,time
sys.stdin.buffer.read()
pid=os.fork()
if pid==0:
 os.setsid()
 fd=os.open("/dev/null",os.O_RDWR)
 for target in (0,1,2): os.dup2(fd,target)
 time.sleep(20); os._exit(0)
print("CHILD_PID:",pid,file=sys.stderr,flush=True)
time.sleep(20)'''
        result = run('/usr/bin/python3', '-c', code, seconds=2)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b'')
        match = re.search(rb'CHILD_PID:\s*(\d+)', result.stderr)
        self.assertIsNotNone(match, result.stderr)
        child = int(match.group(1))
        for _ in range(40):
            try:
                status = Path(f'/proc/{child}/status').read_text()
            except FileNotFoundError:
                break
            if any(line.startswith('State:') and 'Z' in line for line in status.splitlines()):
                break
            time.sleep(0.1)
        else:
            self.fail(f'detached child {child} remained alive after the service stopped')

    def test_individual_file_limit(self):
        code = 'import sys;sys.stdin.buffer.read();open("/tmp/large","wb").write(b"x"*(2*1024*1024))'
        result = run('/usr/bin/python3', '-c', code, file_mib=1)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, b'')

    def test_private_tmp_has_a_real_filesystem_quota(self):
        code = '''import sys
sys.stdin.buffer.read()
try:
 with open("/tmp/bulk","wb") as f:
  for _ in range(40): f.write(b"x"*(1024*1024))
except OSError as error:
 print("ERRNO:",error.errno,file=sys.stderr);sys.exit(9)
sys.exit(0)'''
        result = run('/usr/bin/python3', '-c', code, file_mib=64)
        self.assertEqual(result.returncode, 9, result.stderr)
        self.assertEqual(result.stdout, b'')
        self.assertIn(b'ERRNO: 28', result.stderr)

    def test_ip_sockets_are_blocked(self):
        code = '''import socket,sys
sys.stdin.buffer.read()
try: socket.socket(socket.AF_INET,socket.SOCK_STREAM)
except OSError: print("blocked");sys.exit(0)
sys.exit(9)'''
        result = run('/usr/bin/python3', '-c', code)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, b'blocked\n')


if __name__ == '__main__':
    if sys.platform != 'linux' or os.geteuid() != 0:
        print('Installed systemd worker tests require a disposable Linux system-manager runner.', file=sys.stderr)
        sys.exit(2)
    unittest.main()
