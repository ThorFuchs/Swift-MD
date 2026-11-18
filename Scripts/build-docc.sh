#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Build a DocC archive or a static site without adding a package dependency.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
scratch=${1:-"$root/.build/docc-build"}
output=${2:-"$root/.build/SwiftMD.doccarchive"}
base=${3:-}
mkdir -p "$scratch" "$(dirname -- "$output")"
scratch=$(CDPATH= cd -- "$scratch" && pwd)
output="$(CDPATH= cd -- "$(dirname -- "$output")" && pwd)/$(basename -- "$output")"
cd "$root"
swift package --disable-sandbox --scratch-path "$scratch" dump-symbol-graph --skip-synthesized-members
symbol=$(find "$scratch" -type f -name SwiftMD.symbols.json -print -quit)
test -n "$symbol"
temp=$(mktemp -d "${TMPDIR:-/tmp}/swift-md-docc.XXXXXXXX")
trap 'rm -rf "$temp"' EXIT HUP INT TERM
cp "$symbol" "$temp/SwiftMD.symbols.json"
set -- convert Sources/SwiftMD/SwiftMD.docc --additional-symbol-graph-dir "$temp" \
  --fallback-display-name SwiftMD --fallback-bundle-identifier io.github.thorfuchs.swift-md \
  --fallback-bundle-version 0.1.0 --output-path "$output" --warnings-as-errors
if [ -n "$base" ]; then
  set -- "$@" --transform-for-static-hosting --hosting-base-path "$base"
fi
if command -v docc >/dev/null 2>&1; then docc "$@"; else xcrun docc "$@"; fi
printf 'Documentation archive: %s\n' "$output"
