#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Render or check the research examples with the actual DOCX exporter."""
import argparse
from pathlib import Path
import subprocess
import tempfile
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]
EXAMPLES = ('06-research-light', '07-research-reproducibility')
WORD = '{http://schemas.openxmlformats.org/wordprocessingml/2006/main}'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    binary = args.binary.resolve()
    if not binary.is_file():
        parser.error('missing GalleryDOCX executable')
    with tempfile.TemporaryDirectory(prefix='swiftmd-gallery-docx-') as tmp:
        for stem in EXAMPLES:
            source = ROOT / 'Examples/Markdown' / (stem + '.md')
            target = ROOT / 'Examples/DOCX' / (stem + '.docx')
            result = Path(tmp) / (stem + '.docx')
            subprocess.run([str(binary), str(source), str(result)], check=True)
            subprocess.run(['python3', str(ROOT / 'Scripts/check-docx-fixture.py'), str(result)], check=True)
            with zipfile.ZipFile(result) as archive:
                document = ET.fromstring(archive.read('word/document.xml'))
                text = ' '.join(node.text or '' for node in document.iter(WORD + 't'))
                title = source.read_text(encoding='utf-8').splitlines()[0].removeprefix('# ')
                if title not in text or '$$' not in text or 'mermaid' not in text:
                    raise ValueError(f'{stem}: expected title and visible math/diagram source')
            if args.check:
                if not target.is_file() or target.read_bytes() != result.read_bytes():
                    raise SystemExit(f'DOCX differs or is missing: {target.relative_to(ROOT)}')
            else:
                target.write_bytes(result.read_bytes())
            print(f'{"Checked" if args.check else "Rendered"} {target.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
