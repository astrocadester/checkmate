# Checkmate technical debt

Native source and original ROM devices remain authoritative. Native zmac v1.3 is the only source assembler. Previous Python investigation utilities have been removed from the maintained repository.

| ID | Status | Work / evidence required |
| --- | --- | --- |
| ENG-001 | Implemented, runtime test pending | Native `build.sh` / `build.bat` use bundled zmac v1.3; zero Python execution in build scripts. Confirm on Linux and Windows. |
| ENG-002 | Baseline PASS; edited source pending | User-supplied Linux build confirms four matching SHA-1 devices before v20261120-0003 ASM formatting and data decoding. Static source-width audit covers all 4,096 bytes with 55 unchanged labels unmoved. Re-run native zmac build after cleanup. |
| ENG-003 | Audit | No hardware adapters introduced. Trace board RAM and mirrored I/O ranges against diagrams. |
| ENG-004 | Verification pending | Record zmac build, binary SHA-1, MAME execution and hardware execution as distinct results. |
| RE-001 | Source naming complete; semantic review pending | All generic FLOW and SUBROUTINE labels replaced. Verify descriptive roles while tracing callers. |
| RE-002 | Structured; build verification pending | Font and graphics bytes organized as labeled inline bitmaps; individual high-bit game messages, native pointer tables, animation records and player RAM records labeled; native opcode bytes at $03F3, $07FE, $0AED, $0BFE, $0D4A and $0D6E decoded. Confirm 4 KB binary. |
| RE-003 | In progress | Complete optional language-ROM entry and runtime service study; original `checkmat.d` not supplied. |
| RE-004 | Pending | Match game-specific memory-map mirrors and port semantics to original board diagrams. |

Baseline project engineering requirements: [ENGINEERING-RULES.md](../ENGINEERING-RULES.md). Continue prior native-dispatch work in [Checkmate hard RE](checkmate-hard-re-20261031.md).
