#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Exercise an actual version-resolved consumer of a disposable local distribution.

The local tag is not a release. Never publish this scratch repository.
Requires Swift 6+, Git and reachable real dependencies.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]

def run(*args, cwd=None, env=None):
    subprocess.run(list(map(str, args)), cwd=cwd, env=env, check=True)

def main():
    revision = subprocess.check_output(["git", "-C", str(ROOT), "rev-parse", "HEAD"], text=True).strip()
    with tempfile.TemporaryDirectory(prefix="swiftmdepub-distribution-") as tmp:
        root = Path(tmp)
        repo = root / "SwiftMDEPUB"
        second = root / "second"
        for dest in (repo, second):
            run(sys.executable, ROOT / "Scripts/generate-epub-distribution.py", dest, "--revision", revision)
        origin = json.loads((repo / "DISTRIBUTION-ORIGIN.json").read_text())
        assert (repo / "DISTRIBUTION-ORIGIN.json").read_bytes() == (second / "DISTRIBUTION-ORIGIN.json").read_bytes()
        for name, expected in origin["files_sha256"].items():
            assert hashlib.sha256((repo / name).read_bytes()).hexdigest() == expected
            assert (repo / name).read_bytes() == (second / name).read_bytes()
        # Test the distribution tree itself before a separate version-resolved client.
        evidence = root / "epubs"
        evidence.mkdir()
        run("swift", "test", "--package-path", repo, "-j", "4",
            env={**os.environ, "SWIFTMDEPUB_TEST_OUTPUT": str(evidence)})
        run(sys.executable, repo / "verify_reference.py", evidence)
        run("git", "init", "-q", repo)
        run("git", "-C", repo, "add", ".")
        run("git", "-C", repo, "-c", "user.name=Local Proof", "-c",
            "user.email=local-proof@example.invalid", "commit", "-qm", "Local distribution test only")
        run("git", "-C", repo, "tag", "0.0.0")
        consumer = root / "Consumer"
        consumer.mkdir()
        tests = consumer / "Tests/ConsumerTests"
        tests.mkdir(parents=True)
        (consumer / "Package.swift").write_text(
            "// swift-tools-version: 6.0\nimport PackageDescription\n"
            "let package = Package(name: \"Consumer\", platforms: [.macOS(.v15)], dependencies: ["
            f".package(url: {json.dumps(repo.as_uri())}, exact: \"0.0.0\")], "
            "targets: [.testTarget(name: \"ConsumerTests\", dependencies: "
            "[.product(name: \"SwiftMDEPUB\", package: \"SwiftMDEPUB\")])])\n")
        (tests / "ConsumerTests.swift").write_text(
            'import Foundation\nimport Testing\nimport SwiftMDEPUB\n'
            '@Test func publishedShape() throws {\n'
            '  let source = Data("# Consumer\\n\\n**SwiftMD**\\n".utf8)\n'
            '  let snapshot = try EPUBExporter().compile(source, title: "Consumer", language: "en")\n'
            '  #expect(snapshot.sourceBytes == source)\n'
            '  #expect(try EPUBExporter().render(snapshot).prefix(4) == Data([0x50, 0x4b, 3, 4]))\n'
            '}\n')
        run("swift", "test", "--package-path", consumer, "-j", "4")
        pins = json.loads((consumer / "Package.resolved").read_text())["pins"]
        assert any(p["identity"].lower() == "swiftmdepub" and p["state"].get("version") == "0.0.0" for p in pins)
        print(json.dumps({"source_commit": revision, "local_test_only": True, "resolved": pins}, indent=2))
    print("Isolated versioned consumer proof passed; no remote or release created.")

if __name__ == "__main__":
    main()
