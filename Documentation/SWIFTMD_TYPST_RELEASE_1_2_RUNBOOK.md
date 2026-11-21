# Gated release runbook: Swift-MD 1.2.0 → Adapters 1.3.0 → ViewMarkdown

This runbook is preparation, not permission to bypass the accepted source/mirror release gates. No tag, GitHub Release, or production-app merge is created by these steps until explicitly reviewed and validated.

## Verified mismatch and correct target

- ViewMarkdown currently requests Swift-MD-Adapters **1.0.0** (requires Swift-GFM 1.0.1 and Swift-MD 1.0.0).
- The new optional SwiftMDTypst product was merged into Swift-MD at source revision **dc7247406fcc9336bafb940772e0f90edb7748a5**, requiring Swift-GFM 1.1.0.
- Swift-MD-Adapters **1.2.0** already uses Swift-GFM 1.1.0, but still requires published Swift-MD **1.1.0**, which does NOT include SwiftMDTypst.
- Target generation: a released **Swift-MD 1.2.0** with SwiftMDTypst, a source-generated **Swift-MD-Adapters 1.3.0** requiring Swift-MD 1.2.0 and Swift-GFM 1.1.0, then an app-specific dependency-alignment PR.
- The mirror is generated from **source Swift-MD**, not edited manually. No Swift-GFM downgrade, version-forcing cache cleanup, local user-file overwrite or unauthorized release.

## Step 1 — Review, test and publish Swift-MD 1.2.0 (human GitHub tag/release)

Review the release-readiness PR and check actual GitHub Actions evidence: normal SwiftMD Core and security workflows, optional SwiftMDTypst adapter tests, and the synthetic local mirror distribution gate must all pass. Failure before runner assignment is **not** a pass.

Use a clean source checkout, preferably a *fresh clone* that cannot affect an active Codex worktree:

~~~sh
mkdir -p "$HOME/Projects/swiftmd-releases"
git clone https://github.com/ThorFuchs/Swift-MD.git \
  "$HOME/Projects/swiftmd-releases/Swift-MD-1.2.0"
cd "$HOME/Projects/swiftmd-releases/Swift-MD-1.2.0"
git fetch origin --tags
git switch main
git merge --ff-only origin/main
git status --short --branch
grep -F '.library(name: "SwiftMDTypst"' Package.swift
grep -F 'exact: "1.1.0"' Package.swift
swift test -j 4
swift test --package-path Adapters/SwiftMDTypst -j 4
swift build --product SwiftMDTypst -j 4
~~~

If the new PR or existing source/security workflows are not green, STOP and resolve that before releasing. For an independent distribution check after resolving the local pinned SwiftHTML checkout:

~~~sh
swift package --package-path Adapters/SwiftMDBlocks resolve
python3 Scripts/check-swifthtml-checkout.py
python3 Scripts/test-mirror-policy.py
SWIFTMD_NODE="$(command -v node)" python3 Scripts/test-distribution.py
~~~

Only after successful review and actual tests, an authorized repository maintainer publishes one **immutable annotated** tag:

~~~sh
git status --porcelain
git log -1 --oneline
git ls-remote --tags origin refs/tags/1.2.0
# The remote lookup must show NO 1.2.0 tag.
git tag -a 1.2.0 -m "SwiftMD 1.2.0: optional Typst AST adapter"
git push origin refs/tags/1.2.0
gh release create 1.2.0 --repo ThorFuchs/Swift-MD \
  --title "SwiftMD 1.2.0" \
  --notes "Adds optional SwiftMDTypst semantic source projection (strict subset); Swift-GFM 1.1.0. Existing SwiftMD core HTML API is unchanged."
~~~

Record the final source tag commit. **Never move or force-replace an existing public tag.**

## Step 2 — Generate the official adapters 1.3.0 candidate

Clone the actual tag into a fresh, disposable directory. The source project has a dedicated helper in Scripts/prepare-typst-adapter-mirror.sh. It requires a clean checkout at tag 1.2.0 and then runs the existing verified generator, public tag checks, SHA-512-verified renderer resource loading, and test-public-candidate.py using a *synthetic mirror-only* tag.

~~~sh
ROOT="$(mktemp -d)"
git clone --branch 1.2.0 --depth 1 \
  https://github.com/ThorFuchs/Swift-MD.git "$ROOT/source"
cd "$ROOT/source"
CANDIDATE="$ROOT/adapter-candidate"
bash Scripts/prepare-typst-adapter-mirror.sh \
  "$CANDIDATE" "$(command -v node)"
grep 'exact:' "$CANDIDATE/Package.swift"
cat "$CANDIDATE/MIRROR-ORIGIN.json"
~~~

The generated candidate must have public-tag-verified Swift-MD 1.2.0, Swift-GFM 1.1.0, Swift-Highlight 1.0.1, SwiftHTML 0.1.1; it must record the released source commit, local_test_only **false**, release_review_required **true**, real renderer digests, and no unpublished local dependencies. The script does not publish or mutate GitHub.

## Step 3 — Review mirror PR and publish adapters 1.3.0

Use a separate fresh mirror checkout. In the following commands, rsync --delete is permitted **only for this disposable fresh mirror clone** after inspecting its dry-run; NEVER run it inside the user's existing repositories or worktrees.

~~~sh
git clone https://github.com/ThorFuchs/Swift-MD-Adapters.git \
  "$ROOT/Swift-MD-Adapters"
cd "$ROOT/Swift-MD-Adapters"
git switch -c release/swiftmd-adapters-1.3.0
rsync -av --dry-run --delete --exclude='.git/' "$CANDIDATE/" ./
# Check the dry-run, particularly removed files, before proceeding.
rsync -av --delete --exclude='.git/' "$CANDIDATE/" ./
git status --short
git diff --stat
git diff -- Package.swift MIRROR-ORIGIN.json
git add --all
git commit -m "Generate adapters 1.3.0 from SwiftMD 1.2.0"
git push -u origin release/swiftmd-adapters-1.3.0
gh pr create --repo ThorFuchs/Swift-MD-Adapters \
  --base main --head release/swiftmd-adapters-1.3.0 \
  --title "Release candidate: verified generated adapters 1.3.0" \
  --body "Official generated source from SwiftMD 1.2.0; public tags, source provenance and external renderer digests verified with Scripts/prepare-typst-adapter-mirror.sh."
~~~

After owner approval, merged PR and any required clean consumer/license checks, publish the mirror release from its accepted main:

~~~sh
git switch main
git fetch origin --tags
git merge --ff-only origin/main
git status --short
git ls-remote --tags origin refs/tags/1.3.0
# Must NOT already exist.
git tag -a 1.3.0 -m "Swift-MD-Adapters 1.3.0 from SwiftMD 1.2.0"
git push origin refs/tags/1.3.0
gh release create 1.3.0 --repo ThorFuchs/Swift-MD-Adapters \
  --title "Swift-MD-Adapters 1.3.0" \
  --notes "Verified generated mirror of SwiftMD 1.2.0 and Swift-GFM 1.1.0 with retained renderer and license provenance."
~~~

## Step 4 — Accept the prepared ViewMarkdown alignment PR (after both public tags)

The independent ViewMarkdown PR will change **only**:
- Xcode JSON local Publishing path ../Packages/ViewMarkdownPublishing → Packages/ViewMarkdownPublishing, correcting the proven local directory mismatch.
- Xcode Swift-MD-Adapters 1.0.0 → **1.3.0**.
- Publisher Swift-MD commit pin dc724740 → **exact tag 1.2.0**, with a matching PDF cache-namespace fingerprint.

That PR is deliberately **Draft and not resolvable until both tags exist**. Do not merge on unverified tags.

The user's existing ViewMarkdown working tree has a one-line uncommitted path correction and possibly a generated untracked Package.resolved file. Before using the remote PR locally, inspect and preserve that work explicitly:

~~~sh
cd "$HOME/Projects/ViewMarkdown"
git status --short --branch
git diff -- ViewMarkdown.xcodeproj/project.xcproj
git branch -vv
git worktree list --porcelain
~~~

If the diff is still only the expected package-path line, save a copy of it before deliberately reconciling the local working tree to the later merged remote PR. Do not use destructive blanket reset/clean/rebase/stash commands. Keep any untracked Package.resolved for explicit lockfile review; do not delete it merely to make the solver proceed.

Once the accepted ViewMarkdown PR is merged and a **clean** local main can be fast-forwarded:

~~~sh
git fetch origin --prune
git switch main
git merge --ff-only origin/main
make doctor
make build
make test
swift test --package-path Packages/ViewMarkdownPublishing -j 2
make run
~~~

For release readiness, exercise the *running* App: Continuous → Typst Pages → PDFKit thumbnails → same-titled heading destinations → Continuous; two Reader windows must retain independent navigation and thumbnail state. Check original Markdown SHA-256 unchanged and measure cold/warm PDF rendering. A green SwiftPM package test is not evidence that the actual Xcode Reader runs.

## Stop conditions

- Missing/failing CI gate: **do not tag**.
- Mirror candidate fails public verification: **do not manually rewrite its manifest or provenance**.
- Unresolvable SwiftPM graph after tags: inspect exact manifests and lockfiles, **do not downgrade Swift-GFM or wipe caches**.
- Local ViewMarkdown source/branch changes conflict: preserve and report, never discard another session's work.
