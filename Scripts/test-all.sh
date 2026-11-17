#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
NODE=${SWIFTMD_NODE:-$(command -v node)}
: "${SWIFTMD_CMARK_REFERENCE:?Set SWIFTMD_CMARK_REFERENCE to the independently built pinned cmark-gfm executable}"
test -x "$SWIFTMD_CMARK_REFERENCE" || { echo 'Reference renderer is not executable' >&2; exit 1; }
test -x "$NODE" || { echo 'Node is not executable' >&2; exit 1; }
export SWIFTMD_NODE="$NODE"
export SWIFTMD_KATEX="$ROOT/Tools/NodeDependencies/node_modules/katex"
export SWIFTMD_PELE="$ROOT/Tools/NodeDependencies/node_modules/pele/dist/pele.js"
test -f "$SWIFTMD_KATEX/package.json" && test -f "$SWIFTMD_PELE" || { echo 'Run npm ci --ignore-scripts in Tools/NodeDependencies first' >&2; exit 1; }
(cd "$ROOT" && swift test -j 4)
(cd "$ROOT/Adapters/SwiftMDBlocks" && swift test -j 4)
(cd "$ROOT/Tools/SwiftMDCLI" && swift build -j 4)
python3 "$ROOT/Scripts/test-cli.py"
if [ "$(uname -s)" = Linux ]; then python3 "$ROOT/Scripts/test-linux-limits.py"; fi
