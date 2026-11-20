#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Require the resolved SwiftHTML release commit and unchanged package sources."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
info = json.loads((ROOT / 'Adapters/SwiftMDBlocks/SwiftHTML-PROVENANCE.json').read_text())
adapter = ROOT / 'Adapters/SwiftMDBlocks'
source = adapter / '.build/checkouts/Swift-HTML'


def git(*args):
    return subprocess.check_output(['git', '-c', f'safe.directory={source}',
                                    '-c', f'safe.directory={source / ".git"}',
                                    '-C', str(source), *args], stderr=subprocess.STDOUT).decode()


try:
    pins = json.loads((adapter / 'Package.resolved').read_text())['pins']
    matches = [pin for pin in pins if pin['identity'] == 'swift-html']
    if len(matches) != 1 or matches[0]['state'] != {
        'revision': info['tested_revision'], 'version': info['public_version']
    } or matches[0]['location'] != info['public_repository']:
        raise ValueError('SwiftHTML lockfile pin differs from verified release provenance')
    revision = git('rev-parse', 'HEAD').strip()
    if revision != info['tested_revision']:
        raise ValueError(f'SwiftHTML HEAD {revision} differs from tested {info["tested_revision"]}')
    changes = git('status', '--porcelain', '--untracked-files=all', '--', 'Package.swift', 'Sources',
                  'Vendor/SwiftSoup', 'Scripts/verify-upstream.py').strip()
    if changes:
        raise ValueError('SwiftHTML package source differs from the tested commit')
    print(f'Resolved SwiftHTML checkout: {revision}; tested package files unchanged')
except (OSError, ValueError, subprocess.CalledProcessError) as error:
    print(f'SwiftHTML checkout check failed: {error}', file=sys.stderr)
    sys.exit(1)
