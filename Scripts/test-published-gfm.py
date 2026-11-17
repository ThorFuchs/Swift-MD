#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare the independent published GFM HTML examples, without normalizing output."""
import hashlib
from html.parser import HTMLParser
import os
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = ROOT / 'Tests/PublishedGFM/gfm-0.29.html'
EXPECTED_HASH = 'b153d814fdfc8624bb6da7449162c1cd707a637f7d1c1b636eb44b9cf63fa220'
CLI = Path(os.environ.get('SWIFTMD_CLI', ROOT / 'Tools/SwiftMDCLI/.build/debug/swift-md'))

class Examples(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.depth = 0
        self.current = None
        self.capture = None
        self.items = []

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == 'div' and not self.depth and 'example' in attrs.get('class', '').split() and re.fullmatch(r'example-\d+', attrs.get('id', '')):
            self.depth = 1
            self.current = {'id': attrs['id']}
            return
        if self.depth and tag == 'div':
            self.depth += 1
        if self.depth and tag == 'code' and attrs.get('class') in ('language-markdown', 'language-html'):
            self.capture = attrs['class']
            if self.capture in self.current:
                raise ValueError('duplicate example field')
            self.current[self.capture] = ''

    def handle_endtag(self, tag):
        if self.capture and tag == 'code':
            self.capture = None
        if self.depth and tag == 'div':
            self.depth -= 1
            if self.depth == 0:
                self.items.append(self.current)
                self.current = None

    def handle_data(self, data):
        if self.capture:
            self.current[self.capture] += data

def main():
    data = SNAPSHOT.read_bytes()
    if hashlib.sha256(data).hexdigest() != EXPECTED_HASH:
        raise ValueError('published snapshot checksum mismatch')
    parser = Examples()
    parser.feed(data.decode('utf-8'))
    if parser.depth or len(parser.items) != 677:
        raise ValueError('unexpected or incomplete published example inventory')
    mismatches = []
    for number, example in enumerate(parser.items, 1):
        if example.keys() != {'id', 'language-markdown', 'language-html'} or example['id'] != f'example-{number}':
            raise ValueError(f'malformed example {number}')
        source = example['language-markdown'].replace('→', '\t').encode('utf-8')
        expected = example['language-html'].replace('→', '\t').encode('utf-8')
        result = subprocess.run([str(CLI), '--unsafe-html'], input=source, capture_output=True, check=True)
        if result.stdout != expected:
            mismatches.append(example['id'])
    print(f'Published GFM 0.29: {len(parser.items) - len(mismatches)}/{len(parser.items)} byte-identical; {len(mismatches)} differ')
    if mismatches:
        print('Differing examples: ' + ', '.join(mismatches))
    return 1 if mismatches else 0

if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f'Published GFM comparison failed: {error}', file=sys.stderr)
        sys.exit(2)
