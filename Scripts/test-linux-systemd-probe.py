#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Probe systemd/cgroup-v2 controls on a disposable privileged Linux runner.

This is an environment experiment, not a production SwiftMD sandbox.
"""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import unittest

SYSTEMD = '/usr/bin/systemd-run'


def run(code, seconds=10):
    properties = (
        'DynamicUser=yes', 'NoNewPrivileges=yes', 'CapabilityBoundingSet=',
        'PrivateNetwork=yes', 'RestrictAddressFamilies=AF_UNIX',
        'ProtectSystem=strict', 'ProtectHome=yes', 'ProtectControlGroups=yes',
        'PrivateDevices=yes', 'RestrictNamespaces=yes',
        'MemoryAccounting=yes', 'MemoryMax=128M', 'MemorySwapMax=0',
        'TasksAccounting=yes', 'TasksMax=64', 'LimitFSIZE=8M',
        'TemporaryFileSystem=/tmp:rw,nosuid,nodev,size=32M',
        'TemporaryFileSystem=/var/tmp:rw,nosuid,nodev,size=32M',
        'KillMode=control-group',
        'KillSignal=SIGKILL', 'TimeoutStopSec=1s', f'RuntimeMaxSec={seconds}s',
    )
    command = [SYSTEMD, '--system', '--quiet', '--wait', '--pipe', '--collect', '--service-type=exec']
    for item in properties:
        command.extend(('--property', item))
    return subprocess.run([*command, '--', '/usr/bin/python3', '-c', code],
                          input=b'', capture_output=True, timeout=seconds + 15)


class SystemdProbe(unittest.TestCase):
    def test_effective_controls_and_unprivileged_worker(self):
        code = '''import json,os,resource,socket
from pathlib import Path
group=Path("/sys/fs/cgroup" + Path("/proc/self/cgroup").read_text().strip().split("::",1)[1])
mounts={line.split()[4]:line.split()[5].split(",") for line in Path("/proc/self/mountinfo").read_text().splitlines()}
try:
 fd=os.open(group/"cgroup.procs",os.O_WRONLY); os.close(fd); writable=True
except OSError: writable=False
try:
 s=socket.socket(socket.AF_INET,socket.SOCK_STREAM); s.close(); network=True
except OSError: network=False
print(json.dumps({"uid":os.getuid(),"memory":(group/"memory.max").read_text().strip(),
 "swap":(group/"memory.swap.max").read_text().strip(),"tasks":(group/"pids.max").read_text().strip(),
 "writable":writable,"network":network,"rootro":"ro" in mounts["/"],"cgro":"ro" in mounts["/sys/fs/cgroup"],
 "file":resource.getrlimit(resource.RLIMIT_FSIZE)[0],
 "tmp":os.statvfs("/tmp").f_blocks*os.statvfs("/tmp").f_frsize,
 "vartmp":os.statvfs("/var/tmp").f_blocks*os.statvfs("/var/tmp").f_frsize}))'''
        result = run(code)
        self.assertEqual(result.returncode, 0, result.stderr)
        info = json.loads(result.stdout)
        self.assertNotEqual(info['uid'], 0)
        self.assertEqual(info['memory'], str(128 * 1024 * 1024))
        self.assertEqual(info['swap'], '0')
        self.assertEqual(info['tasks'], '64')
        self.assertFalse(info['writable'])
        self.assertFalse(info['network'])
        self.assertTrue(info['rootro'] and info['cgro'])
        self.assertEqual(info['file'], 8 * 1024 * 1024)
        self.assertLessEqual(info['tmp'], 32 * 1024 * 1024)
        self.assertLessEqual(info['vartmp'], 32 * 1024 * 1024)

    def test_cgroup_kills_new_session_descendant(self):
        code = '''import os,time
pid=os.fork()
if pid==0:
 os.setsid()
 fd=os.open("/dev/null",os.O_RDWR)
 for target in (0,1,2): os.dup2(fd,target)
 time.sleep(20); os._exit(0)
print(pid,flush=True)
time.sleep(20)'''
        result = run(code, seconds=2)
        self.assertNotEqual(result.returncode, 0, 'runtime deadline was not enforced')
        child = int(result.stdout.strip())
        for _ in range(40):
            try:
                status = Path(f'/proc/{child}/status').read_text()
            except FileNotFoundError:
                break
            if any(line.startswith('State:') and 'Z' in line for line in status.splitlines()):
                break
            time.sleep(0.1)
        else:
            self.fail(f'detached child {child} remained alive after the unit stopped')

    def test_aggregate_memory_limit(self):
        code = '''import os,time
print("allocating",flush=True)
children=[]
for i in range(3):
 pid=os.fork()
 if pid==0:
  data=bytearray(72*1024*1024); time.sleep(3); os._exit(0)
 children.append(pid)
failed=False
for pid in children:
 try:
  _,status=os.waitpid(pid,0); failed |= not os.WIFEXITED(status) or os.WEXITSTATUS(status)!=0
 except ChildProcessError: failed=True
os._exit(42 if failed else 0)'''
        result = run(code)
        self.assertIn(b'allocating', result.stdout, result.stderr)
        self.assertNotEqual(result.returncode, 0, 'three independent allocations unexpectedly exceeded no aggregate limit')


if __name__ == '__main__':
    if sys.platform != 'linux' or os.geteuid() != 0:
        print('This disposable systemd probe requires Linux and root.', file=sys.stderr)
        sys.exit(2)
    unittest.main()
