#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Diagnose published GFM examples against an independently built C backend."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location('published_gfm', ROOT / 'Scripts/test-published-gfm.py')
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)
EXTENSIONS = ('table', 'strikethrough', 'autolink', 'tagfilter', 'tasklist')


def examples():
    data = MODULE.SNAPSHOT.read_bytes()
    if hashlib.sha256(data).hexdigest() != MODULE.EXPECTED_HASH:
        raise ValueError('published snapshot checksum mismatch')
    parser = MODULE.Examples()
    parser.feed(data.decode('utf-8'))
    if parser.depth or len(parser.items) != 677:
        raise ValueError('unexpected published example inventory')
    for number, item in enumerate(parser.items, 1):
        if item.keys() != {'id', 'language-markdown', 'language-html'} or item['id'] != f'example-{number}':
            raise ValueError(f'malformed example {number}')
    return parser.items


def text(item, key):
    return item[key].replace('→', '\t')


def swiftmd(source):
    return subprocess.run([str(MODULE.CLI), '--unsafe-html'], input=source, capture_output=True, check=True).stdout


def cmark(reference, source, extensions):
    command = [str(reference), '--unsafe']
    for extension in extensions:
        command += ['-e', extension]
    return subprocess.run(command, input=source, capture_output=True, check=True).stdout


def main():
    args = argparse.ArgumentParser(description=__doc__)
    args.add_argument('--reference', type=Path, help='independently built pinned cmark-gfm executable')
    args.add_argument('--browser-cases', action='store_true', help='emit selected HTML pairs as JSON for browser DOM tests')
    options = args.parse_args()
    items = examples()
    if options.browser_cases:
        rows = []
        for number in (279, 280, 649, 650):
            item = items[number - 1]
            source = text(item, 'language-markdown').encode('utf-8')
            rows.append({'number': number, 'expected': text(item, 'language-html'), 'actual': swiftmd(source).decode('utf-8')})
        print(json.dumps(rows, ensure_ascii=True))
        return 0
    if options.reference is None:
        args.error('--reference is required unless --browser-cases is used')
    configs = {
        'all': EXTENSIONS,
        'without_tagfilter': tuple(x for x in EXTENSIONS if x != 'tagfilter'),
        'without_autolink': tuple(x for x in EXTENSIONS if x != 'autolink'),
        'without_tagfilter_or_autolink': tuple(x for x in EXTENSIONS if x not in ('tagfilter', 'autolink')),
    }
    mismatches = {name: [] for name in configs}
    backend_differences = []
    for number, item in enumerate(items, 1):
        source = text(item, 'language-markdown').encode('utf-8')
        expected = text(item, 'language-html').encode('utf-8')
        actual = swiftmd(source)
        for name, extensions in configs.items():
            reference = cmark(options.reference, source, extensions)
            if reference != expected:
                mismatches[name].append(number)
            if name == 'all' and reference != actual:
                backend_differences.append(number)
    for name, failures in mismatches.items():
        print(f'{name}: {len(items) - len(failures)}/{len(items)} exact; {len(failures)} differ')
    print('Known baseline only: 26 published examples differ; this is not a conformance pass.')
    print('all profile differing examples:', ', '.join(map(str, mismatches['all'])))
    print('SwiftMD vs independent C differences:', backend_differences or 'none (677/677 match)')
    if backend_differences:
        return 1
    # Check exact case identities, not just counts; backend changes need review.
    baseline = {140, 141, 142, 145, 147, 279, 280, 324, 398, 426, 434, 435,
                436, 473, 474, 475, 477, 611, 615, 617, 620, 621, 634, 635, 649, 650}
    tag_cases = {140, 141, 142, 145, 147}
    auto_cases = {611, 615, 617, 620, 621}
    extension_cases = set(range(622, 634))
    expected = {
        'all': baseline,
        'without_tagfilter': (baseline - tag_cases) | {657},
        'without_autolink': (baseline - auto_cases) | extension_cases,
        'without_tagfilter_or_autolink': (baseline - tag_cases - auto_cases) | {657} | extension_cases,
    }
    for name, failures in mismatches.items():
        if set(failures) != expected[name]:
            print(f'Unexpected differing cases for {name}: {failures}', file=sys.stderr)
            return 1
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Published GFM analysis failed: {error}', file=sys.stderr)
        sys.exit(2)
