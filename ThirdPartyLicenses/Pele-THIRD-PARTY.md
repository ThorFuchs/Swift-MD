# Notices and build evidence for Pele 1.13.0

Pele's upstream `LICENSE` contains its MIT license and the ISC notice for the
Lucide icon; the unmodified text is in `Pele-MIT.txt` and is included alongside
the bundled resources.

On 18 November 2026, Pele's `1.13.0` tag was checked at commit
`3a2f075ee0c3d914f0fad3545fc0f193693975ac`. Using esbuild 0.28.2 from the
upstream lockfile and the upstream build settings, the ESM and IIFE files were
rebuilt byte-for-byte against the SHA-512-verified npm archive:

| File | SHA-256 |
| --- | --- |
| `dist/pele.js` | `37bea5005aa6d2dde929032ced5d2958cf642667cbc1fe675f9dfacf4ba15a51` |
| `dist/pele.global.js` | `0b0a46c57a5a6971670c09f5ec4066705bd78505f90fd11adf6260325efa0910` |

The esbuild metafiles record 243 inputs each: Pele's `src/` files and its
`package.json`; no `node_modules` source files were included. The global
build's metafile also identifies esbuild's synthetic `<runtime>` helpers.
The esbuild 0.28.2 MIT license is retained as `Pele-esbuild-MIT.txt` and is
included with the resources. It was copied from the npm archive whose SHA-512
integrity is specified in Pele's pinned `package-lock.json`; its SHA-256 is
`b40ec5baec7bb34fa5b1c09521fa3cd52d5fad7adafed74932a2010d3612a681`.

The build settings omit legal comments. This inventory and reproducibility
evidence do not establish the origin or licensing of every upstream source
fragment and are not a legal clearance to publish the mirror.
