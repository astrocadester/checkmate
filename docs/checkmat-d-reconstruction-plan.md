# Checkmate — checkmat.d language ROM reconstruction plan

**Status:** Proposed engineering work; implementation requires approval under [ENGINEERING-RULES.md](../ENGINEERING-RULES.md).  
**Target:** Optional 1 KB Intel 8080 language ROM `checkmat.d`, mapped at `$1000–$13FF`.  
**Baseline:** The four original devices `checkmat.h`, `checkmat.g`, `checkmat.f`, `checkmat.e` and their byte-exact native build remain unchanged.

## Objective

Reconstruct a **functionally compatible language device** that works with Checkmate's existing native selector, drawing routines and game control. The device should supply the language-specific introductory display, round-result presentation and message-address data expected by the resident program.

The source of the reconstruction must be identified as new work. Its bytes will have a separate checksum and must never be represented as a dump of DNA's `checkmat.d`.

## Confirmed resident-ROM interface

The selector `SELECT_LANGUAGE_VECTOR` at `$0DE8` reads input port `$02`, rotates language bits 5–6 into an index from 0 through 3, then enters the indexed 16-bit pointer helper at `$0C9C`. The **caller** supplies the table address in `HL`.

| Call site | Resident table | English (index 0) | Index 1 | Index 2 | Index 3 | Result |
| --- | --- | --- | --- | --- | --- | --- |
| Intro, `$0621` | `$0E3C` | `$0628` | `$1000` | `$1003` | `$1006` | Selected native routine, `JP (HL)` |
| Round/result, `$0898` | `$0E44` | `$089F` | `$1009` | `$100C` | `$100F` | Selected native routine, `JP (HL)` |
| Text-pointer helper, `$0DD4` | `$0E4C` | `$0E24` | `$1020` | `$1040` | `$1060` | Message-address-table base |

The exact original-language text, machine code, register side effects and complete data layout of the missing ROM are still to be established.

### How the message lookup works

The resident code at `SELECT_LANGUAGE_MESSAGE_POINTER` (`$0DD4`) performs two distinct pointer lookups:

```asm
SELECT_LANGUAGE_MESSAGE_POINTER:
        LD HL,$0E1A
        LD A,D
        CALL LOOKUP_INDEXED_WORD_POINTER
        PUSH HL
        LD HL,$0E4C
        CALL SELECT_LANGUAGE_VECTOR
        LD A,E
        CALL LOOKUP_INDEXED_WORD_POINTER
        POP DE
        RET
```

The first lookup uses `D` and the resident table at `$0E1A`. The second chooses the language-specific base at `$0E4C`, then indexes that base with `E`. The resulting `HL` points to the selected text; `DE` carries the saved value from the first lookup. Examine both callers (`DRAW_HIGH_BIT_TERMINATED_MESSAGE` and `DRAW_ZERO_TERMINATED_MESSAGE`) and the resident English data before implementing this contract. In particular, confirm whether `E` is always a zero-based word index and inventory the maximum index reached.

## Candidate ROM organization

Only the entry addresses and the message-base addresses are known. The following allocation is **an implementation hypothesis**, not a recovered original layout.

| Range | Proposed role | Evidence / constraint |
| --- | --- | --- |
| `$1000–$1008` | Three intro entry stubs | Entries at `$1000`, `$1003`, `$1006`; 3-byte spacing suggests `JP` stubs |
| `$1009–$1011` | Three round-result entry stubs | Entries at `$1009`, `$100C`, `$100F`; same hypothesis |
| `$1012–$101F` | Native code or alignment | Unassigned; investigate size constraints |
| `$1020`, `$1040`, `$1060` | Three message-table bases | Directly selected by resident `$0E4C` table |
| Remaining bytes through `$13FF` | Translated messages and shared native routines | To be allocated after contracts and message lengths are measured |

Do not assume each message table is exactly `$20` bytes long merely because its base addresses are `$20` apart. Trace the actual index range and compare memory occupation before deciding whether to relocate strings, share code or use compact jump stubs.

## Implementation stages

### Stage 1 — Finish the interface RE

1. Read the full English intro routine `LANGUAGE0_INTRO_RENDER` at `$0628` and the round-result routine `LANGUAGE0_ROUND_SETUP` at `$089F`, including all paths that return or fall through into shared native code.
2. Record an **entry/exit contract** for each: incoming register values, preserved registers, flags where relevant, stack behavior, display memory expectations, RAM side effects and next control-flow destination.
3. Trace every call to `DRAW_HIGH_BIT_TERMINATED_MESSAGE` and `DRAW_ZERO_TERMINATED_MESSAGE`. Record each observed `D/E` selector pair, its English message address, and its screen destination.
4. Decode the English base `$0E24` as a real word-address table, and determine the total number and order of entries accessed. Use labels in the existing source for confirmed structures.
5. Inventory the English strings, control bytes, encoded spaces (`$40`), high-bit terminators and rendering behavior, including player numbers and round-result text.
6. Verify the three non-English cabinet settings and their language names against the hardware/manual evidence; keep the index-to-language mapping separate from assumptions.

**Deliverable:** A small address/ABI table with observed caller states, message indices, control-flow destinations and source locations. Correct source labels only where code tracing supports the change.

### Stage 2 — Design a compatible 1 KB implementation

1. Determine how the six fixed entry addresses can be occupied without collisions. Test the three-byte `JP` stub hypothesis against the native contracts.
2. Place three language-specific message pointer tables at the required bases `$1020`, `$1040` and `$1060`, with an entry for every verified index.
3. Reuse the resident ROM's native display, font, timing, player-selection and round-result services. Write only the additional 8080 code required to satisfy the interface.
4. Encode translated messages in the same byte format as the English data. Preserve text control bytes, line behavior and high-bit termination. Validate actual text layout on screen.
5. Produce a memory allocation table for all `$0400` bytes and fail the build if an allocation exceeds `$13FF`.
6. If behavior or size cannot be established from available evidence, document the obstacle and proposed deviation **before** implementation.

**Gate:** Explicit approval of the new functional reconstruction and of any language text or native behavior that must be authored rather than recovered.

### Stage 3 — Build separately with native zmac

Suggested tree, once approved:

```text
src/
  checkmate.asm                    # byte-exact resident ROM
  language-rom/
    checkmat-d-reconstruction.asm  # new Intel 8080 source
build/                             # all generated binaries and listings
roms/
  original/checkmat.zip            # untouched reference
  checkmat.zip                     # canonical four-device native build
  experimental/                    # untracked test ROM set(s)
```

- Assemble the reconstruction with the repository's bundled **zmac v1.3**, as a standalone `ORG $1000` program. Do not invoke Python in the build.
- Keep the canonical `build.sh` / `build.bat` and original four-device verification unchanged.
- Add a separate named experimental Linux/Windows build command that assembles the 1 KB image, checks its size, creates a separate experimental MAME ZIP containing the four unchanged resident devices plus reconstructed `checkmat.d`, and prints the checksum of the reconstructed device.
- Assemble from native `ASM` source; use shell/batch only for orchestration, byte-count checks, checksums and ZIP packaging. Do not use generated source, replacement parsers or alternate compilers.
- Ensure all experimental binaries, listings and generated ROM ZIPs are ignored by Git. Keep the reconstruction source and concise documentation tracked.
- If MAME still reports a missing or mismatched language ROM, inspect the driver-required filename, expected length and ROM identity. Run an experimental set only through a test configuration that reports the constructed device's identity accurately. Do not modify the original source or falsely designate the new bytes as a dumped original.

### Stage 4 — Exercise all four settings in MAME

Test the same game events in each language setting:

| Case | What to verify |
| --- | --- |
| Boot / attract | Game initializes and presents appropriate text |
| Coin / credit | Credits and prompts are readable and positioned correctly |
| Player selection | One-to-four-player instructions, numbering and control inputs |
| Round end | Result, winner/tie wording and scoreboard rendering |
| Multiple rounds | No broken return paths, register/stack corruption or state drift |
| Boundary cases | Longest translations, last message index, low/high language indices |

Log screenshots or video, the language switch setting, CPU trace or relevant breakpoint results, and any text/formatting deviations. Verify that English (index 0) still follows its resident paths and that the four resident devices are byte-exact to their original SHA-1 hashes.

### Stage 5 — Document results

- Add an implementation memory map, source layout and native ABI notes to this document.
- Label verified behavior, inferred structure and newly implemented behavior distinctly.
- Record assembler success, original-bank comparisons, experimental ROM checksum, MAME execution and physical hardware results as separate evidence.
- Update [SPRINT-PLAN.md](SPRINT-PLAN.md) and [TECHNICAL-DEBT.md](TECHNICAL-DEBT.md) only with stages actually completed.
- Keep the canonical Checkmate ROM and original ROM reference files unchanged throughout.

## First engineering task

**Trace and document the resident English message lookup at `$0DD4`, beginning with its `$0E24` table base.** Create the complete `D/E` selector inventory and cross-reference it to the English messages. This determines the minimum compatible structure at `$1020`, `$1040` and `$1060`. Then establish the native entry/exit contracts for `$0628` and `$089F`.

No reconstructed ROM source, test binary or substituted language content is authorized by this planning document alone.
