# Checkmate sprint plan

Governance: [ENGINEERING-RULES.md](../ENGINEERING-RULES.md) and [AGENTS.md](../AGENTS.md). Native Intel 8080 source and original ROM bytes own the game semantics. The native build uses zmac v1.3 without source regeneration.

## Current cleanup — v20261120-0003

- [x] Preserve reference `roms/original/checkmat.zip` unchanged.
- [x] Replace Python-dependent build with direct native assembler invocation on Linux.
- [x] Add equivalent Windows batch build.
- [x] Split four 1 KB devices and verify SHA-1 before generating `roms/checkmat.zip`.
- [x] Move generated intermediates to untracked root `build/`; remove tracked historical outputs from PR branch.
- [x] Match Desert Gun project README layout.
- [x] Create Checkmate memory map in the supplied graphic style with a game-specific emblem.
- [x] Clean source formatting and make selected flow labels descriptive, without altering assembly statements.
- [x] Linux native build and original 1 KB device SHA-1 verification on v20261120-0002 predecessor (user-supplied output).
- [ ] Re-run Linux native build after assembly source cleanup and verify all four device hashes.
- [ ] Execute Windows build and record device verification output.
- [x] Confirm baseline 4 KB image and four device SHA-1 values from supplied Linux build output.
- [ ] Execute `mame checkmat -rompath roms -window -skip_gameinfo` and capture runtime result.
- [x] Replace all remaining generic `FLOW_xxxx` and `SUBROUTINE_xxxx` symbols with role-oriented labels.
- [x] Classify DB regions into font glyphs, drawing records, message data, pointer tables and padding; decode identified executable DB sequences.
- [x] Format blank lines before header comments and place comments directly above sections.
- [x] Replace overflowing memory-map design with Extra Inning chip styling; rename unmapped areas.
- [x] Remove duplicate original-folder PDFs and obsolete Python RE generators; preserve original ZIP.
- [ ] Verify interpretation of individual game lookup records and sound routines against code and board documents.
- [ ] Verify memory mirrors and I/O against board schematics.

## PR gate

State native source/toolchain, original-ROM authority, changes, actual tests, open items and deviations. Do not claim executable or emulator verification from a source-only audit. No alternate 8080 compiler, synthetic gameplay or substituted graphics without prior approval.
