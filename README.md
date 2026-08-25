# USBSCSI.R4P

`USBSCSI.R4P` is an independent R4OS protocol module implemented in Zig.

## Package

- Version: `0.1.2`
- Image target: `/R4OS/PROTOCOLS/USBSCSI.R4P`
- Image scope: `slim`
- Canonical project manifest: `module.R4MF`

The manifest is the single source of truth for the artifact, imports, image
target, and package metadata.

The protocol builds READ CAPACITY(10/16), READ/WRITE(10/16), inquiry, sense,
mode and cache CDBs. Transfer sizes use the reported logical block size; a
READ CAPACITY(10) sentinel selects the 64-bit capacity response required for
media beyond the 32-bit LBA boundary.

## Build

On Windows:

    Build.bat

On Linux or macOS:

    ./Build.sh

The build starters resolve the current local R4OS dependency checkouts through
`Settings.R4S`. The URL and hash entries in `build.zig.zon` record the
last verified standalone dependency identities; workspace builds use the
mapped local checkouts.

## Documentation

Detailed German technical notes from the migration are preserved in
`DOCUMENTATION.de.txt`. Source-transfer provenance is recorded in
`PROVENANCE.txt`.

## License

Original R4OS material is licensed under Apache License 2.0. See `LICENSE`
and `NOTICE`. Any repository-specific external material is documented in
`THIRD_PARTY_NOTICES.md`.
