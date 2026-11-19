#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Fail if a CodeQL SARIF result is missing or contains unresolved findings."""
import json
from pathlib import Path
import sys

REQUIRED = {
    'swift': {
        'Sources/SwiftMD/MarkdownCompiler.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDBlocks/Blocks.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDBlocks/ValidatedSVG.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDHighlight/Highlight.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDKaTeXNode/KaTeX.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDPeleNode/Pele.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDCompiler/SwiftMDRenderer.swift',
        'Adapters/SwiftMDBlocks/Sources/SwiftMDJavaScriptCore/JavaScriptCoreRenderer.swift',
        '_security_scan_swifthtml/Sources/SwiftHTML/SwiftHTML.swift',
        '_security_scan_swifthtml/Vendor/SwiftSoup/Sources/Parser.swift',
        '_security_scan_swifthtml/Vendor/SwiftSoup/Sources/Tokeniser.swift',
        '_security_scan_swifthtml/Vendor/SwiftSoup/Sources/HtmlTreeBuilder.swift',
        '_security_scan_swifthtml/Vendor/SwiftSoup/Sources/Element.swift',
        '_security_scan_mirror/Adapters/SwiftMDBlocks/Sources/SwiftMDBundled/SwiftMDIntegrated.swift',
        '_security_scan_mirror/Tools/SwiftMDCLI/Sources/SwiftMDCLI/main.swift',
    },
    'python': {
        'Scripts/generate-adapter-mirror.py',
        'Scripts/audit-dependencies.py',
        'Scripts/check-swifthtml-checkout.py',
        'Scripts/run-linux-supervised.py',
        'Scripts/run-linux-systemd.py',
        'Scripts/systemd-worker-guard.py',
        'Scripts/check-codeql-results.py',
    },
}


def main():
    if len(sys.argv) != 3 or sys.argv[2] not in REQUIRED:
        raise ValueError('provide the CodeQL SARIF output directory and language (swift or python)')
    language = sys.argv[2]
    diagnostic_language = 'py' if language == 'python' else language
    files = sorted(Path(sys.argv[1]).glob('*.sarif'))
    if not files:
        raise ValueError('CodeQL produced no SARIF files')
    findings = 0
    extracted = set()
    for path in files:
        data = json.loads(path.read_text(encoding='utf-8'))
        if data.get('version') != '2.1.0':
            raise ValueError(f'{path.name} is not SARIF 2.1.0')
        runs = data.get('runs')
        if not isinstance(runs, list) or not runs:
            raise ValueError(f'{path.name} has no analysis runs')
        for run in runs:
            if run.get('tool', {}).get('driver', {}).get('name', '').lower() != 'codeql':
                raise ValueError(f'{path.name} is not a CodeQL analysis')
            invocation = run.get('invocations', [])
            if not invocation or any(item.get('executionSuccessful') is not True for item in invocation):
                raise ValueError(f'{path.name} reports an unsuccessful analysis')
            for item in invocation:
                for notice in item.get('toolExecutionNotifications', []):
                    if notice.get('descriptor', {}).get('id') != f'{diagnostic_language}/diagnostics/successfully-extracted-files':
                        continue
                    for location in notice.get('locations', []):
                        uri = location.get('physicalLocation', {}).get('artifactLocation', {}).get('uri')
                        if uri:
                            extracted.add(uri)
            for result in run.get('results', []):
                findings += 1
                location = (result.get('locations') or [{}])[0].get('physicalLocation', {})
                file = location.get('artifactLocation', {}).get('uri', '<unknown>')
                line = location.get('region', {}).get('startLine', '?')
                print(f"{result.get('ruleId', '<unknown>')}: {file}:{line}")
    missing = REQUIRED[language] - extracted
    if missing:
        raise ValueError(f'{language} scan did not extract required files: {", ".join(sorted(missing))}')
    print(f'CodeQL findings: {findings} across {len(files)} SARIF file(s); {len(REQUIRED[language])} required files extracted')
    return 1 if findings else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f'CodeQL result check failed: {error}', file=sys.stderr)
        sys.exit(2)
