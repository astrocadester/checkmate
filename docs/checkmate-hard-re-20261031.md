# Checkmate native program architecture

Checkmate (1977), developed by Dave Nutting Associates for Midway, uses native Intel 8080 routines for game control, player state, graphics and messages. Its four resident 1 KB ROM devices form a 4 KB program at `$0000–$0FFF`.

## Shared native services

Checkmate uses the 8080's single-byte `RST` calls to reach three common services:

| Call | Native entry | Purpose |
| --- | --- | --- |
| `RST $18` | `$0D7D` | Wait on a countdown while servicing game frames |
| `RST $20` | `$0CA8` | Advance or wrap the player index |
| `RST $28` | `$0C99` | Look up the current player's 16-bit table entry |

The lookup helper at `$0C9C` takes an index and table address, reads a little-endian 16-bit value, and returns that value in `HL`. The caller uses the value as a pointer or code entry address.

## Language selection

The language setting is encoded in bits 5–6 of input port `$02`. The native selector at `$0DE8` rotates those bits into a two-bit index (`0–3`) and looks up a 16-bit routine address from a table. The calling code jumps through `HL` to execute that routine.

| Language setting index | Intro routine table at `$0E3C` | Round-result table at `$0E44` |
| --- | --- | --- |
| 0 — English | `$0628` | `$089F` |
| 1 | `$1000` | `$1009` |
| 2 | `$1003` | `$100C` |
| 3 | `$1006` | `$100F` |

The English paths reside in the main ROM. Entries `$1000–$100F` reference the additional `checkmat.d` language ROM. This ROM supported the cabinet's other language selections; its contents have not been dumped in the available MAME set.

The selector chooses among already-written native routines. An interpreter executes a program stream containing encoded commands, repeatedly fetching an instruction, finding its handler and continuing to the next instruction. In Checkmate, `DW` stores native addresses and `RST` calls native services; these are not TERSE or other interpreted-language words.

## Display and game data

The source identifies the resident English messages beginning at `$0E54`, including player prompts, start-game instructions and round-result messages. Two pointer tables select spelled-out player numbers (`$0F01`) and round-result text (`$0F18`). Font, drawing, animation and player-state tables are labeled alongside the native routines in [the disassembly](../src/checkmate.asm).

## Build

`./build.sh` assembles the source with bundled zmac v1.3, verifies all four original 1 KB device SHA-1 hashes and writes the MAME set to `roms/checkmat.zip`. The complete cleaned source passed all four SHA-1 checks in the user-reported Linux build on November 20, 2026. MAME launched with its known missing-`checkmat.d` warning.

For the ROM address layout, see the [memory map](../images/checkmate-memory-map.svg).
