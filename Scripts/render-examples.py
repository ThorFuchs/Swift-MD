#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Render the gallery with the real CLI; optionally check HTML or capture Chrome previews."""
import argparse
import html
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / 'Examples'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--node', type=Path, required=True)
    parser.add_argument('--chrome', type=Path)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    if args.check and args.chrome:
        parser.error('--check and --chrome cannot be combined')
    binary, node = args.binary.resolve(), args.node.resolve()
    katex = ROOT / 'Tools/NodeDependencies/node_modules/katex'
    pele = ROOT / 'Tools/NodeDependencies/node_modules/pele/dist/pele.js'
    sources = sorted((EXAMPLES / 'Markdown').glob('*.md'))
    if not sources or not binary.is_file() or not node.is_file() or not katex.is_dir() or not pele.is_file():
        parser.error('missing examples, CLI, Node or installed locked Node dependencies')
    for source in sources:
        prefix = 'swiftmd-example-' + source.stem
        command = [str(binary), '--strict', '--highlight', '--katex-node', str(node), '--katex-module', str(katex),
                   '--pele-node', str(node), '--pele-module', str(pele), '--svg-prefix', prefix, str(source)]
        output = subprocess.run(command, check=True, capture_output=True).stdout
        target = EXAMPLES / 'HTML' / (source.stem + '.html')
        if args.check:
            if not target.is_file() or target.read_bytes() != output:
                raise SystemExit(f'HTML differs or is missing: {target.relative_to(ROOT)}')
        else:
            target.write_bytes(output)
            if args.chrome:
                with tempfile.TemporaryDirectory(prefix='swiftmd-gallery-') as tmp:
                    temp = Path(tmp)
                    css = (EXAMPLES / 'preview.css').read_text(encoding='utf-8')
                    title = html.escape(source.stem[3:].replace('-', ' '))
                    page = temp / 'preview.html'
                    page.write_text('<!doctype html><html lang="en"><meta charset="utf-8">'
                                    f'<style>{css}</style><div class="frame"><div class="label">SwiftMD · {title}</div>'
                                    f'{output.decode("utf-8")}</div></html>', encoding='utf-8')
                    subprocess.run([str(args.chrome.resolve()), '--headless', '--disable-gpu', '--disable-javascript',
                                    '--hide-scrollbars', '--force-device-scale-factor=1', '--window-size=800,600',
                                    f'--user-data-dir={temp / "profile"}',
                                    f'--screenshot={EXAMPLES / "Images" / (source.stem + ".png")}', page.as_uri()],
                                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f'{"Checked" if args.check else "Rendered"} {source.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
