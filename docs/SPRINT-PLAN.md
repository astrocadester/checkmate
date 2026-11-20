# Checkmate sprint plan

Governance: [ENGINEERING-RULES.md](../ENGINEERING-RULES.md) and [AGENTS.md](../AGENTS.md). Native Intel 8080 source and original ROM bytes own the game semantics. The native build uses zmac v1.3 without source regeneration.

## Current cleanup — v20261120-0001

- [x] Preserve reference `roms/original/checkmat.zip` unchanged.
- [x] Replace Python-dependent build with direct native assembler invocation on Linux.
- [x] Add equivalent Windows batch build.
- [x] Split four 1 KB devices and verify SHA-1 before generating `roms/checkmat.zip`.
- [x] Move generated intermediates to untracked root `build/`; remove tracked historical outputs from PR branch.
- [x] Match Desert Gun project README layout.
- [x] Create Checkmate memory map in the supplied graphic style with a game-specific emblem.
- [x] Clean source formatting and make selected flow labels descriptive, without altering assembly statements.
- [ ] Execute both native scripts on the respective operating systems and record command output.
- [ ] Confirm assembled 4 KB binary and four device SHA-1 values.
- [ ] Execute `mame checkmat -rompath roms -window -skip_gameinfo` and capture runtime result.
- [ ] Complete remaining generic `FLOW_xxxx` names using traced control flow.
- [ ] Classify remaining DB regions: font glyphs, drawing records, strings, pointer tables and padding.
- [ ] Verify memory mirrors and I/O against board schematics.

## PR gate

State native source/toolchain, original-ROM authority, changes, actual tests, open items and deviations. Do not claim executable or emulator verification from a source-only audit. No alternate 8080 compiler, synthetic gameplay or substituted graphics without prior approval.
