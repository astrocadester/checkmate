# Checkmate technical debt

Native source and original ROM devices remain authoritative. Native zmac v1.3 is the only source assembler. Previous Python investigation utilities have been removed from the maintained repository.

| ID | Status | Work / evidence required |
| --- | --- | --- |
| ENG-001 | Linux PASS; Windows pending | User executed the final-source `build.sh` with bundled zmac v1.3. `build.bat` remains untested on Windows. |
| ENG-002 | PASS | Final-source v20261120-0006 Linux zmac build generated all four 1 KB ROMs with expected SHA-1 values and packaged `roms/checkmat.zip` (user-supplied console transcript). |
| ENG-003 | Audit | No hardware adapters introduced. Trace board RAM and mirrored I/O ranges against diagrams. |
| ENG-004 | Build PASS; MAME launched | SHA-1 checks PASS. MAME ran for approximately six seconds at 100% average speed; undumped `checkmat.d` warning. Visual/gameplay, Windows and physical hardware evidence remain open. |
| RE-001 | Source naming complete; semantic review pending | All generic FLOW and SUBROUTINE labels replaced. Verify descriptive roles while tracing callers. |
| RE-002 | Byte-exact build PASS | Font and graphics bytes organized as labeled inline bitmaps; individual high-bit game messages, native pointer tables, animation records and player RAM records labeled; native opcode bytes at $03F3, $07FE, $0AED, $0BFE, $0D4A and $0D6E decoded. Final ROM banks match reference SHA-1 values. |
| RE-003 | In progress | Complete optional language-ROM entry and runtime service study; original `checkmat.d` not supplied. |
| RE-004 | Pending | Match game-specific memory-map mirrors and port semantics to original board diagrams. |

Baseline project engineering requirements: [ENGINEERING-RULES.md](../ENGINEERING-RULES.md). Continue prior native-dispatch work in [Checkmate hard RE](checkmate-hard-re-20261031.md).
