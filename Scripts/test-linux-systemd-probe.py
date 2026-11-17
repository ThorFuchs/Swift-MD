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
import tempfile
import time
import unittest

SYSTEMD = '/usr/bin/systemd-run'


def run(code, seconds=10):
    with tempfile.TemporaryDirectory(prefix='swiftmd-probe-', dir='/run') as work:
        properties = (
            'DynamicUser=yes', 'NoNewPrivileges=yes', 'CapabilityBoundingSet=',
            'PrivateNetwork=yes', 'RestrictAddressFamilies=AF_UNIX AF_INET',
            'ProtectSystem=strict', 'ProtectHome=yes', 'ProtectControlGroups=yes',
            'PrivateDevices=yes', 'RestrictNamespaces=yes',
            'MemoryAccounting=yes', 'MemoryMax=128M', 'MemorySwapMax=0',
            'TasksAccounting=yes', 'TasksMax=64', 'LimitFSIZE=8M',
            f'TemporaryFileSystem={work}:rw,nosuid,nodev,size=32M,mode=1777',
            'InaccessiblePaths=/tmp /var/tmp', f'Environment=TMPDIR={work}',
            f'Environment=SWIFTMD_HOST_NET_INODE={os.stat("/proc/1/ns/net").st_ino}',
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
interfaces={line.split(":",1)[0].strip() for line in Path("/proc/net/dev").read_text().splitlines() if ":" in line}
with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as receiver, socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as sender:
 receiver.settimeout(.5); receiver.bind(("127.0.0.1",0)); sender.sendto(b"x",receiver.getsockname()); loopback=receiver.recv(1)==b"x"
try:
 s=socket.socket(socket.AF_INET6,socket.SOCK_STREAM); s.close(); ipv6=True
except OSError: ipv6=False
print(json.dumps({"uid":os.getuid(),"memory":(group/"memory.max").read_text().strip(),
 "swap":(group/"memory.swap.max").read_text().strip(),"tasks":(group/"pids.max").read_text().strip(),
 "writable":writable,"ipv6":ipv6,"loopback":loopback,"interfaces":sorted(interfaces),
 "privateNet":os.stat("/proc/self/ns/net").st_ino!=int(os.environ["SWIFTMD_HOST_NET_INODE"]),
 "rootro":"ro" in mounts["/"],"cgro":"ro" in mounts["/sys/fs/cgroup"],
 "file":resource.getrlimit(resource.RLIMIT_FSIZE)[0],
 "tmp":os.statvfs(os.environ["TMPDIR"]).f_blocks*os.statvfs(os.environ["TMPDIR"]).f_frsize,
 "tmpWritable":os.access("/tmp",os.W_OK),"vartmpWritable":os.access("/var/tmp",os.W_OK)}))'''
        result = run(code)
        self.assertEqual(result.returncode, 0, result.stderr)
        info = json.loads(result.stdout)
        self.assertNotEqual(info['uid'], 0)
        self.assertEqual(info['memory'], str(128 * 1024 * 1024))
        self.assertEqual(info['swap'], '0')
        self.assertEqual(info['tasks'], '64')
        self.assertFalse(info['writable'])
        self.assertFalse(info['ipv6'])
        self.assertTrue(info['privateNet'] and info['loopback'])
        self.assertEqual(info['interfaces'], ['lo'])
        self.assertTrue(info['rootro'] and info['cgro'])
        self.assertEqual(info['file'], 8 * 1024 * 1024)
        self.assertLessEqual(info['tmp'], 32 * 1024 * 1024)
        self.assertFalse(info['tmpWritable'] or info['vartmpWritable'])

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
