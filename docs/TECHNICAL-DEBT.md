# Checkmate technical debt

Native source and original ROM devices remain authoritative. Investigation tools under `tools/*.py` are not part of the production build.

| ID | Status | Work / evidence required |
| --- | --- | --- |
| ENG-001 | Implemented, runtime test pending | Native `build.sh` / `build.bat` use bundled zmac v1.3; zero Python execution in build scripts. Confirm on Linux and Windows. |
| ENG-002 | Verification pending | Assemble `src/checkmate.asm` and compare every 1 KB bank with the original SHA-1 reference. |
| ENG-003 | Audit | No hardware adapters introduced. Trace board RAM and mirrored I/O ranges against diagrams. |
| ENG-004 | Verification pending | Record zmac build, binary SHA-1, MAME execution and hardware execution as distinct results. |
| RE-001 | In progress | Replace remaining generic `FLOW_xxxx` labels using named, traced behavior. |
| RE-002 | In progress | Identify and annotate residual DB arrays, font rows, messages, pointer tables and padding without changing original bytes. |
| RE-003 | In progress | Complete optional language-ROM entry and runtime service study; original `checkmat.d` not supplied. |
| RE-004 | Pending | Match game-specific memory-map mirrors and port semantics to original board diagrams. |

Baseline project engineering requirements: [ENGINEERING-RULES.md](../ENGINEERING-RULES.md). Continue prior native-dispatch work in [Checkmate hard RE](checkmate-hard-re-20261031.md).
