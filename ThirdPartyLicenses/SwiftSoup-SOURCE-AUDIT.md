# SwiftSoup source distribution review

SwiftMD's generated adapter package depends on the public SwiftSoup 2.11.3 tag,
commit `d86f244ed497d48012782e2f59c985a55e77b3f5`. Its root `LICENSE` is MIT
and is retained in `SwiftSoup-MIT.txt`. SwiftPM fetches the upstream source
package separately; these test files are not copied into the SwiftMD-generated
adapter mirror and are not part of SwiftSoup's declared library target.

The pinned source snapshot also contains six saved web pages under
`Tests-macOS/corpus/`: Amazon, GitHub, Google, Reuters, Wikipedia and Wirecutter.
For example, `Google.html`, SHA-256
`094d6a66d4540a9539eb02315b830bc7219a4e141893d4dd5f5757125c7fd46c`,
contains an embedded Math.uuid.js comment identifying Robert Kieffer and dual
MIT/GPL licensing, and another comment identifying Closure Authors and
MochiKit. The file also contains material presented as a Google page. Git
history attributes the file's addition to SwiftSoup commit
`5da0b123b9b2223028e97cfd3709bf697a2f6ad0`; that records the import, not the
rights chain of each part of the page.

On 19 November 2026, the newer public SwiftSoup 2.14.4 tag still contained all
six named corpus files. Its `Google.html` has the same Git blob
`a215fa8a4324caae3841af5c78c600c265a877bc` as the pinned 2.11.3 snapshot.
Updating to that tag alone therefore does not remove this particular issue.

ScanCode Toolkit 33.0.0rc1 reported an MIT-or-GPL reference in that Google
fixture. The root package license and this match do not establish the terms
of every external page or embedded component in the corpus. This observation
is not a conclusion of infringement. Review the upstream source package's
fixture rights and distribution conditions, or select and verify a distribution
that does not include the material, before treating the source-dependency
review as complete. Preserve the distinction between the SwiftMD mirror's own
files and packages a consumer fetches separately.

The SwiftSoup library source and its independently fetched package are governed
by their own notices. This file does not modify SwiftSoup or determine the
legal status of any third-party material.
