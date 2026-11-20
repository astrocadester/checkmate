# Checkmate sprint plan

Governance: [ENGINEERING-RULES.md](../ENGINEERING-RULES.md) and [AGENTS.md](../AGENTS.md). Native Intel 8080 source and original ROM bytes own the game semantics. The native build uses zmac v1.3 without source regeneration.

## Current cleanup — v20261120-0008

- [x] Preserve reference `roms/original/checkmat.zip` unchanged.
- [x] Replace Python-dependent build with direct native assembler invocation on Linux.
- [x] Add equivalent Windows batch build.
- [x] Split four 1 KB devices and verify SHA-1 before generating `roms/checkmat.zip`.
- [x] Move generated intermediates to untracked root `build/`; remove tracked historical outputs from PR branch.
- [x] Match Desert Gun project README layout.
- [x] Create Checkmate memory map in the supplied graphic style with a game-specific emblem.
- [x] Clean source formatting and make selected flow labels descriptive, without altering assembly statements.
- [x] Linux native build and original 1 KB device SHA-1 verification on v20261120-0002 predecessor (user-supplied output).
- [x] Re-run Linux native build after assembly source cleanup; all four device SHA-1 hashes match originals (user-supplied terminal output, v20261120-0006).
- [ ] Execute Windows build and record device verification output.
- [x] Confirm baseline 4 KB image and four device SHA-1 values from supplied Linux build output.
- [x] Launch `mame checkmat -rompath roms -window -skip_gameinfo`: process ran at 100% average speed for approximately six seconds and reported missing undumped optional `checkmat.d` (user-supplied output).
- [ ] Record an in-game visual/input gameplay check, separate from successful MAME process launch.
- [x] Replace all remaining generic `FLOW_xxxx` and `SUBROUTINE_xxxx` symbols with role-oriented labels.
- [x] Classify DB regions into font glyphs, drawing records, message data, pointer tables and padding; decode identified executable DB sequences.
- [x] Name each high-bit-terminated English display message and express native address tables as `DW` words, including player-number and round-result text pointers.
- [x] Format blank lines before header comments and place comments directly above sections.
- [x] Replace overflowing memory-map design with Extra Inning chip styling; rename unmapped areas.
- [x] Remove duplicate original-folder PDFs and obsolete Python RE generators; preserve original ZIP.
- [x] Center labels and captions in the SVG memory map; remove excess qualification text and main-ROM subtitle.
- [x] Rewrite the README and language-dispatch technical note as concise, affirmative descriptions of native execution.
- [x] Render 19 named text DB records as readable assembler string fragments, preserving encoded spaces, controls and high-bit terminators; static comparison confirms all 242 original text bytes match.
- [ ] Run final zmac SHA-1 verification after readable string-literal source changes.
- [ ] Verify interpretation of individual game lookup records and sound routines against code and board documents.
- [ ] Verify memory mirrors and I/O against board schematics.

- [x] Trace all three language-selector callers at $0621, $0898 and $0DD4 and document code-jump versus message-pointer uses.
- [x] Add evidenced arcade development credits to ASM, README and native architecture documentation.
- [x] Explain native selector versus script interpreter with concise side-by-side table.
- [ ] Rebuild after documentation-only ASM header/comment revisions to re-confirm ROM hashes.

## Independent source-layout audit

The v20261120-0004 source contains exactly 4,096 addressable bytes by static instruction-width and directive counting. All 55 unchanged labels retained their addresses. Font data begins at $0197; game graphic records at $04AB; native code at $0D4A; the language intro vectors at $0E3C; and zero-filled tail at $0FF2. The final v20261120-0006 source subsequently assembled with bundled zmac v1.3 and passed all four original device SHA-1 comparisons in the user's Linux build.

## PR gate

State native source/toolchain, original-ROM authority, changes, actual tests, open items and deviations. Do not claim executable or emulator verification from a source-only audit. No alternate 8080 compiler, synthetic gameplay or substituted graphics without prior approval.
