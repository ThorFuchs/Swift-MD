#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Generate an isolated SwiftMDEPUB repository root from committed SwiftMD sources.

No remote, release, tag, credentials or network operation. The output is a
review candidate, not a published distribution.
"""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PREFIX = "Adapters/SwiftMDEPUB/"
NOTICES = (
    "LICENSE",
    "ThirdPartyLicenses/SwiftGFM-Apache-2.0.txt",
    "ThirdPartyLicenses/SwiftGFM-NOTICE.txt",
    "ThirdPartyLicenses/cmark-gfm-COPYING.txt",
)

def git(*args):
    return subprocess.check_output(["git", "-C", str(ROOT), *args])

def generate(revision, destination):
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("use the full immutable source commit SHA")
    if git("rev-parse", revision + "^{commit}").decode().strip() != revision:
        raise ValueError("revision must identify the exact commit")
    entries = git("ls-tree", "-r", "-z", revision, "--", PREFIX, *NOTICES)
    files = {}
    for entry in entries.split(b"\0"):
        if not entry:
            continue
        header, raw = entry.split(b"\t", 1)
        mode, kind, object_id = header.decode("ascii").split()
        path = raw.decode("utf-8")
        if mode != "100644" or kind != "blob":
            raise ValueError("unexpected source file mode/type: " + path)
        if path in NOTICES:
            target = path
        elif path.startswith(PREFIX):
            target = path[len(PREFIX):]
            if target not in {"Package.swift", "README.md", "verify_reference.py", "Package.resolved"} and not target.startswith(("Sources/SwiftMDEPUB/", "Tests/SwiftMDEPUBTests/")):
                raise ValueError("unreviewed adapter path: " + path)
        else:
            raise ValueError("unexpected source path")
        p = PurePosixPath(target)
        if p.is_absolute() or ".." in p.parts or "\\" in target or target in files:
            raise ValueError("unsafe or duplicate path")
        if int(git("cat-file", "-s", object_id)) > 8 * 1024 * 1024:
            raise ValueError("unexpectedly large source blob")
        files[target] = git("cat-file", "blob", object_id)
    required = {"Package.swift", "README.md", "verify_reference.py",
                "Sources/SwiftMDEPUB/EPUBExporter.swift",
                "Tests/SwiftMDEPUBTests/Fixtures/Reference.md", *NOTICES}
    if not required.issubset(files):
        raise ValueError("missing required source or notices")
    if len(files) > 128 or sum(map(len, files.values())) > 16 * 1024 * 1024:
        raise ValueError("distribution budget exceeded")
    manifest = {
        "schema": 1, "source_repository": "https://github.com/ThorFuchs/Swift-MD",
        "source_commit": revision, "source_directory": PREFIX.rstrip("/"),
        "release_review_required": True,
        "files_sha256": {p: hashlib.sha256(b).hexdigest() for p,b in sorted(files.items())},
    }
    files["DISTRIBUTION-ORIGIN.json"] = (json.dumps(manifest, indent=2, sort_keys=True) + "\n").encode()
    files[".gitignore"] = b".build/\n.swiftpm/\n.DS_Store\n__pycache__/\n"
    destination.mkdir(parents=False, exist_ok=False)
    for name, content in sorted(files.items()):
        path = destination / name
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("xb") as out:
            out.write(content)
    return manifest

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--revision", required=True)
    args = parser.parse_args()
    print(json.dumps(generate(args.revision, args.destination), indent=2))

if __name__ == "__main__":
    main()
