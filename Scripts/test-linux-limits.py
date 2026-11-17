#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise actual Linux rlimits and group termination in disposable workers."""
from pathlib import Path
import os
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
WRAPPER = ROOT / 'Scripts/run-linux-constrained.sh'
NODE = os.environ.get('SWIFTMD_NODE', 'node')

def run(*args, seconds='5', memory='8192', file_size='2'):
    return subprocess.run([str(WRAPPER), seconds, memory, file_size, '--', *args], capture_output=True, timeout=15)

class LinuxLimits(unittest.TestCase):
    def test_node_inherits_limits(self):
        code = "console.log(require('fs').readFileSync('/proc/self/limits','utf8'))"
        result = run(NODE, '-e', code)
        self.assertEqual(result.returncode, 0, result.stderr)
        lines = result.stdout.decode().splitlines()
        self.assertTrue(any(line.startswith('Max address space') and '8589934592' in line for line in lines))
        self.assertTrue(any(line.startswith('Max file size') and '2097152' in line for line in lines))

    def test_address_space_is_enforced(self):
        code = "import mmap; mmap.mmap(-1, 9*1024**3)"
        result = run('python3', '-c', code)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'Cannot allocate memory', result.stderr)

    def test_file_size_is_enforced(self):
        with tempfile.TemporaryDirectory() as tmp:
            output = Path(tmp) / 'oversize'
            result = run('python3', '-c', 'import sys; open(sys.argv[1],"wb").write(b"x"*(3*1024**2))', str(output))
            self.assertNotEqual(result.returncode, 0)
            self.assertLessEqual(output.stat().st_size, 2 * 1024**2)

    def test_timeout_kills_worker_and_child(self):
        with tempfile.TemporaryDirectory() as tmp:
            sentinel = Path(tmp) / 'survived'
            child = 'import time,pathlib,sys;time.sleep(2);pathlib.Path(sys.argv[1]).write_text("survived")'
            parent = 'import subprocess,sys,time;subprocess.Popen([sys.executable,"-c",sys.argv[1],sys.argv[2]]);time.sleep(10)'
            started = time.monotonic()
            result = run('python3', '-c', parent, child, str(sentinel), seconds='1')
            self.assertNotEqual(result.returncode, 0)
            self.assertLess(time.monotonic() - started, 5)
            time.sleep(2.2)
            self.assertFalse(sentinel.exists(), 'child escaped the timed process group')

    def test_detached_descendant_is_not_a_sandbox(self):
        # A deliberately detached child is outside timeout's process group. It
        # exits by itself after recording this known isolation boundary.
        with tempfile.TemporaryDirectory() as tmp:
            sentinel = Path(tmp) / 'detached'
            child = 'import time,pathlib,sys;time.sleep(2);pathlib.Path(sys.argv[1]).write_text("detached")'
            parent = ('import os,subprocess,sys,time;'
                      'subprocess.Popen([sys.executable,"-c",sys.argv[1],sys.argv[2]],'
                      'preexec_fn=os.setsid,stdin=subprocess.DEVNULL,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL);'
                      'time.sleep(10)')
            result = run('python3', '-c', parent, child, str(sentinel), seconds='1')
            self.assertNotEqual(result.returncode, 0)
            time.sleep(2.2)
            self.assertTrue(sentinel.exists(), 'detached-child behavior changed; reassess the documented boundary')

if __name__ == '__main__': unittest.main()
