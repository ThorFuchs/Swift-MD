#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Build a public-dependency-verified mirror from exact released Swift-MD 1.2.0.
# No repository mutation, push, tag, or publication happens here.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "usage: bash Scripts/prepare-typst-adapter-mirror.sh <new-absolute-candidate-dir> [node-binary]" >&2
  exit 64
fi

root="$(git rev-parse --show-toplevel)"
cd "$root"
candidate="$1"
if [[ "$candidate" != /* || -e "$candidate" ]]; then
  echo "Candidate must be a new, non-existing absolute path: $candidate" >&2
  exit 64
fi
if [[ -n "$(git status --porcelain --untracked-files=all)" ]]; then
  echo "Source checkout must be clean (including untracked files)." >&2
  exit 65
fi
source_commit="$(git rev-parse HEAD)"
release_commit="$(git rev-parse 'refs/tags/1.2.0^{commit}')"
if [[ "$source_commit" != "$release_commit" ]]; then
  echo "HEAD does not match the published Swift-MD 1.2.0 tag." >&2
  echo "Use a disposable, clean checkout at tag 1.2.0." >&2
  exit 65
fi

if [[ $# -eq 2 ]]; then
  node_bin="$2"
else
  node_bin="$(command -v node || true)"
fi
if [[ -z "$node_bin" || ! -x "$node_bin" ]]; then
  echo "A trusted executable Node binary is required." >&2
  exit 65
fi

python3 Scripts/generate-adapter-mirror.py "$candidate" \
  --core-version 1.2.0 \
  --gfm-version 1.1.0 \
  --highlight-version 1.0.1 \
  --swifthtml-url https://github.com/ThorFuchs/Swift-HTML.git \
  --swifthtml-version 0.1.1 \
  --verify-public-dependencies \
  --include-locked-renderers

python3 Scripts/test-public-candidate.py "$candidate" --node "$node_bin"

python3 - "$candidate" "$source_commit" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
expected = sys.argv[2]
receipt = json.loads((root / "MIRROR-ORIGIN.json").read_text())
dependencies = receipt["dependencies"]
assert receipt["source_commit"] == expected
assert receipt["local_test_only"] is False
assert receipt["release_review_required"] is True
assert dependencies["CORE_VERSION"] == "1.2.0"
assert dependencies["GFM_VERSION"] == "1.1.0"
assert dependencies["HIGHLIGHT_VERSION"] == "1.0.1"
assert dependencies["SWIFTHTML_VERSION"] == "0.1.1"
assert receipt["verified_public_tags"]["swift-md"]["version"] == "1.2.0"
package = (root / "Package.swift").read_text()
assert 'exact: "1.2.0"' in package
assert 'exact: "1.1.0"' in package
assert "LOCAL TEST ONLY" not in package
assert "file://" not in package
print("PUBLIC MIRROR CANDIDATE VERIFIED: Core 1.2.0 + GFM 1.1.0")
print("Source:", expected)
print("Candidate:", root)
print("No release, tag, push, or repository mutation performed.")
PY
