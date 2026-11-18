#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Fail if a CodeQL SARIF result is missing or contains unresolved findings."""
import json
from pathlib import Path
import sys


def main():
    if len(sys.argv) != 2:
        raise ValueError('provide the CodeQL SARIF output directory')
    files = sorted(Path(sys.argv[1]).glob('*.sarif'))
    if not files:
        raise ValueError('CodeQL produced no SARIF files')
    findings = 0
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
            if any(item.get('executionSuccessful') is False for item in invocation):
                raise ValueError(f'{path.name} reports an unsuccessful analysis')
            for result in run.get('results', []):
                findings += 1
                location = (result.get('locations') or [{}])[0].get('physicalLocation', {})
                file = location.get('artifactLocation', {}).get('uri', '<unknown>')
                line = location.get('region', {}).get('startLine', '?')
                print(f"{result.get('ruleId', '<unknown>')}: {file}:{line}")
    print(f'CodeQL findings: {findings} across {len(files)} SARIF file(s)')
    return 1 if findings else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f'CodeQL result check failed: {error}', file=sys.stderr)
        sys.exit(2)
