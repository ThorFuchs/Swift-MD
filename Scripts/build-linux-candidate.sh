#!/bin/sh
# SPDX-License-Identifier: Apache-2.0
# Creates a local candidate only. It does not sign, tag, push or publish.
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
[ "$(uname -s)" = Linux ] || { echo 'Linux is required' >&2; exit 1; }
[ "$#" -eq 1 ] || { echo 'Usage: build-linux-candidate.sh OUTPUT.tar.gz' >&2; exit 2; }
[ ! -e "$1" ] || { echo 'Output already exists' >&2; exit 1; }
[ -d "$(dirname -- "$1")" ] || { echo 'Output directory does not exist' >&2; exit 1; }
[ -z "$(git -C "$ROOT" status --porcelain --untracked-files=all)" ] || { echo 'Source checkout must be clean' >&2; exit 1; }
case "$1" in /*) output=$1;; *) output=$(pwd)/$1;; esac
commit=$(git -C "$ROOT" rev-parse HEAD)
swift_path=$(readlink -f "$(command -v swift)")
swift_license=$(CDPATH= cd -- "$(dirname -- "$swift_path")/../share/swift" && pwd)/LICENSE.txt
[ -f "$swift_license" ] || { echo 'Swift runtime license not found' >&2; exit 1; }
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT HUP INT TERM
swift build --package-path "$ROOT/Tools/SwiftMDCLI" -c release -j "${SWIFTMD_JOBS:-2}" -Xswiftc -no-whole-module-optimization --static-swift-stdlib --disable-automatic-resolution
binpath=$(swift build --package-path "$ROOT/Tools/SwiftMDCLI" -c release --show-bin-path)
mkdir -p "$tmp/SwiftMD/bin" "$tmp/SwiftMD/licenses" "$tmp/SwiftMD/node-dependencies" "$tmp/SwiftMD/isolation"
cp "$binpath/swift-md" "$tmp/SwiftMD/bin/swift-md"
cp "$ROOT/LICENSE" "$tmp/SwiftMD/licenses/SwiftMD-Apache-2.0.txt"
cp "$swift_license" "$tmp/SwiftMD/licenses/Swift-runtime-LICENSE.txt"
cp "$ROOT"/ThirdPartyLicenses/* "$tmp/SwiftMD/licenses/"
cp "$ROOT/Tools/NodeDependencies/package.json" "$ROOT/Tools/NodeDependencies/package-lock.json" "$tmp/SwiftMD/node-dependencies/"
cp "$ROOT/Scripts/run-linux-constrained.sh" "$ROOT/Scripts/run-linux-supervised.py" "$ROOT/Scripts/run-linux-systemd.py" "$ROOT/Scripts/systemd-worker-guard.py" "$ROOT/Documentation/PROCESS_ISOLATION.md" "$tmp/SwiftMD/isolation/"
cat > "$tmp/SwiftMD/README.txt" <<'TEXT'
LOCAL RELEASE CANDIDATE — NOT A PUBLISHED RELEASE
The executable is built with --static-swift-stdlib but still needs system
libraries. Inspect SYSTEM-LIBRARIES.txt on the target. Node and npm packages
are not bundled. Install the locked packages in node-dependencies with
`npm ci --ignore-scripts`, and supply trusted absolute executable/module paths.
Optional Linux worker scripts are under isolation/; the systemd profile requires
a separately configured root-owned installation and suitable systemd/cgroups.
Read the retained licenses and notices before distribution. This archive does
not certify security, GFM conformance, or compatibility with other platforms.
TEXT
{
  printf 'Source commit: %s\n' "$commit"
  printf 'System: '; uname -a
  printf 'Swift: '; swift --version | tr '\n' ' '; printf '\n'
  printf 'Node: '; if command -v node >/dev/null; then node --version; else printf 'not installed\n'; fi
  printf 'Build flags: -c release -Xswiftc -no-whole-module-optimization --static-swift-stdlib\n'
} > "$tmp/SwiftMD/PROVENANCE.txt"
ldd "$tmp/SwiftMD/bin/swift-md" > "$tmp/SwiftMD/SYSTEM-LIBRARIES.txt"
(cd "$tmp/SwiftMD" && find . -type f ! -name SHA256SUMS -print0 | LC_ALL=C sort -z | xargs -0 sha256sum > SHA256SUMS)
tar -C "$tmp" -czf "$output" SwiftMD
sha256sum "$output"
printf 'Local candidate built from %s: %s\n' "$commit" "$output"
