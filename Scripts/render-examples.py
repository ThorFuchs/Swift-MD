#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Render the gallery with the real CLI; optionally check HTML or capture Chrome previews."""
import argparse
import html
from html.parser import HTMLParser
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ROOT / 'Examples'
RESEARCH_EXAMPLES = {'06-research-light', '07-research-reproducibility'}


class ResearchOutput(HTMLParser):
    def __init__(self):
        super().__init__()
        self.math = []
        self.svg = []
        self.highlighted = False
        self.script = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'math':
            self.math.append(attrs)
        elif tag == 'svg':
            self.svg.append(attrs)
        elif tag == 'script':
            self.script = True
        if 'hljs-' in attrs.get('class', ''):
            self.highlighted = True


def check_research_output(source, output):
    text = output.decode('utf-8')
    parsed = ResearchOutput()
    parsed.feed(text)
    math_ns = 'http://www.w3.org/1998/Math/MathML'
    svg_ns = 'http://www.w3.org/2000/svg'
    if not (any(m.get('xmlns') == math_ns and m.get('display') != 'block' for m in parsed.math)
            and any(m.get('xmlns') == math_ns and m.get('display') == 'block' for m in parsed.math)
            and any(s.get('xmlns') == svg_ns and s.get('viewbox') for s in parsed.svg)
            and 'viewBox=' in text and parsed.highlighted and not parsed.script):
        raise ValueError(f'{source.name}: missing MathML, SVG, highlighting or script-free output')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--node', type=Path, required=True)
    parser.add_argument('--chrome', type=Path)
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--only', help='render only the example with this filename stem')
    args = parser.parse_args()
    if args.check and args.chrome:
        parser.error('--check and --chrome cannot be combined')
    binary, node = args.binary.resolve(), args.node.resolve()
    katex = ROOT / 'Tools/NodeDependencies/node_modules/katex'
    pele = ROOT / 'Tools/NodeDependencies/node_modules/pele/dist/pele.js'
    sources = sorted((EXAMPLES / 'Markdown').glob('*.md'))
    if args.only:
        sources = [source for source in sources if source.stem == args.only]
    if not sources or not binary.is_file() or not node.is_file() or not katex.is_dir() or not pele.is_file():
        parser.error('missing examples, CLI, Node or installed locked Node dependencies')
    for source in sources:
        prefix = 'swiftmd-example-' + source.stem
        command = [str(binary), '--strict', '--highlight', '--katex-node', str(node), '--katex-module', str(katex),
                   '--pele-node', str(node), '--pele-module', str(pele), '--svg-prefix', prefix, str(source)]
        if source.stem in RESEARCH_EXAMPLES:
            command.insert(1, '--markdown-math')
        output = subprocess.run(command, check=True, capture_output=True).stdout
        if source.stem in RESEARCH_EXAMPLES:
            check_research_output(source, output)
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
                                    '--hide-scrollbars', '--force-device-scale-factor=1',
                                    '--window-size=900,1000' if source.stem in RESEARCH_EXAMPLES else '--window-size=800,600',
                                    f'--user-data-dir={temp / "profile"}',
                                    f'--screenshot={EXAMPLES / "Images" / (source.stem + ".png")}', page.as_uri()],
                                   check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(f'{"Checked" if args.check else "Rendered"} {source.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
