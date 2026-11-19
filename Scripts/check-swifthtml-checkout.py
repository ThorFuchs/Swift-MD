#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Require the locally tested SwiftHTML commit and unchanged package sources."""
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
info = json.loads((ROOT / 'Adapters/SwiftMDBlocks/SwiftHTML-PROVENANCE.json').read_text())
source = (ROOT / 'Adapters/SwiftMDBlocks' / info['local_sibling']).resolve()


def git(*args):
    return subprocess.check_output(['git', '-c', f'safe.directory={source}',
                                    '-c', f'safe.directory={source / ".git"}',
                                    '-C', str(source), *args], stderr=subprocess.STDOUT).decode()


try:
    revision = git('rev-parse', 'HEAD').strip()
    if revision != info['tested_revision']:
        raise ValueError(f'SwiftHTML HEAD {revision} differs from tested {info["tested_revision"]}')
    changes = git('status', '--porcelain', '--untracked-files=all', '--', 'Package.swift', 'Sources',
                  'Vendor/SwiftSoup', 'Scripts/verify-upstream.py').strip()
    if changes:
        raise ValueError('SwiftHTML package source differs from the tested commit')
    print(f'Local SwiftHTML checkout: {revision}; tested package files unchanged')
except (OSError, ValueError, subprocess.CalledProcessError) as error:
    print(f'SwiftHTML checkout check failed: {error}', file=sys.stderr)
    sys.exit(1)
