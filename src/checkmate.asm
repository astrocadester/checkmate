;*******************************************************************************
; CHECKMATE (1977)
;*******************************************************************************
; Four-player arcade game for Midway Intel 8080 hardware.
;
; Developer : Dave Nutting Associates (DNA)
; Publisher : Midway Manufacturing
; CPU       : Intel 8080
; Software  : Native game routines, RST services, language selectors
;
; ROM       : checkmat.h / checkmat.g / checkmat.f / checkmat.e
; Build     : zmac v1.3; four 1 KB ROM devices
;*******************************************************************************

        ORG $0000
; ROM device checkmat.h — SHA-1 f758599d6393398a6a8e6e7399dc1a3862604f65
; Reset: clear output latch and enter startup diagnostic.

RESET_ENTRY:
        NOP
        NOP
        XOR A
        OUT ($01),A
        JP BOOT_ROM_RAM_DIAGNOSTIC
; Interrupt path 0: save registers, scan coin and timers without player input branch.

IRQ_VBLANK_ENTRY:
        PUSH AF
        PUSH BC
        PUSH DE
        LD B,$00
        JP IRQ_COMMON_INPUT_SCAN
; Interrupt path 1: save registers and select player-input scan.

IRQ_TICK_ENTRY:
        PUSH AF
        PUSH BC
        PUSH DE
        LD B,$01
        JP IRQ_COMMON_INPUT_SCAN
; Jump vector followed by packed high-bit-terminated MAT label bytes.

RST18_TIMER_VECTOR:
        JP RST18_WAIT_TIMER
        DB $08,$4D,$41,$54,$C5 ; ROM $001B entry-vector inline high-bit-terminated label
; Jump vector followed by packed high-bit-terminated COIN label bytes.

RST20_PLAYER_INDEX_VECTOR:
        JP RST20_WRAP_PLAYER_INDEX
        DB $08,$43,$4F,$49,$CE ; ROM $0023 entry-vector inline high-bit-terminated label
; Direct entry to game message routine.

RST28_LOOKUP_VECTOR:
        JP RST28_INDEXED_LOOKUP
; Shared IRQ body: sample port 03, decrement timers, capture four input nibbles.

IRQ_COMMON_INPUT_SCAN:
        PUSH HL
        CALL SAMPLE_COIN_EDGE
        LD A,B
        RRCA
        JP NC,IRQ_RESTORE_REGISTERS
        LD HL,$2003
        CALL DEC_NONZERO_TIMER
        LD HL,$21BE
        CALL DEC_NONZERO_TIMER
        INC HL
        CALL DEC_NONZERO_TIMER
        IN A,($00)
        AND $0F
        JP Z,IRQ_SCAN_PLAYER_ONE_LOW
        LD ($21C2),A
        LD A,$01
        LD ($21C1),A

IRQ_SCAN_PLAYER_ONE_LOW:
        IN A,($00)
        RRCA
        RRCA
        RRCA
        RRCA
        AND $0F
        JP Z,IRQ_SCAN_PLAYER_ONE_HIGH
        LD ($21CA),A

IRQ_SCAN_PLAYER_ONE_HIGH:
        IN A,($01)
        AND $0F
        JP Z,IRQ_SCAN_PLAYER_TWO_LOW
        LD ($21D2),A

IRQ_SCAN_PLAYER_TWO_LOW:
        IN A,($01)
        RRCA
        RRCA
        RRCA
        RRCA
        AND $0F
        JP Z,IRQ_RESTORE_REGISTERS
        LD ($21DA),A
; Restore 8080 registers, re-enable interrupts and return.

IRQ_RESTORE_REGISTERS:
        POP HL
        POP DE
        POP BC
        POP AF
        EI
        RET
; Stable port-03 sample detection; record changed high coin-edge bit in RAM 2001.

SAMPLE_COIN_EDGE:
        IN A,($03)
        LD C,A
        IN A,($03)
        CP C
        RET NZ
        LD HL,$2000
        XOR (HL)
        LD (HL),C
        AND C
        AND $80
        RET Z
        INC HL
        LD (HL),A
        RET
; Decrement byte at HL only when already nonzero.

DEC_NONZERO_TIMER:
        LD A,(HL)
        AND A
        RET Z
        DEC (HL)
        RET
; Startup tests: port 02 gate, RAM patterns and ROM checksums.

BOOT_ROM_RAM_DIAGNOSTIC:
        IN A,($02)
        AND $80
        JP Z,BOOT_GAME_INIT
        LD B,$01
        LD DE,$0000
; Begin RAM pattern pass with pointer HL at 2000.

DIAG_RAM_PASS_BEGIN:
        LD HL,$2000
; Walk candidate RAM and compare against test pattern B.

DIAG_RAM_FORWARD_SCAN:
        OUT ($02),A
        LD (HL),B
        LD A,(HL)
        XOR B
        JP Z,DIAG_RAM_FORWARD_NEXT
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,DIAG_RAM_RECORD_ODD_ERROR
        OR D
        LD D,A
        JP DIAG_RAM_FORWARD_NEXT

DIAG_RAM_RECORD_ODD_ERROR:
        OR E
        LD E,A

DIAG_RAM_FORWARD_NEXT:
        INC HL
        LD A,H
        CP $40
        JP NZ,DIAG_RAM_FORWARD_SCAN
; Reverse RAM sweep; accumulate changed bits in D/E.

DIAG_RAM_REVERSE_SCAN:
        OUT ($02),A
        DEC HL
        LD A,H
        CP $1F
        JP Z,DIAG_RAM_FINAL_SCAN
        LD A,(HL)
        XOR B
        JP Z,DIAG_RAM_WRITE_COMPLEMENT
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,DIAG_RAM_RECORD_REVERSE_ODD
        OR D
        LD D,A
        JP DIAG_RAM_WRITE_COMPLEMENT

DIAG_RAM_RECORD_REVERSE_ODD:
        OR E
        LD E,A

DIAG_RAM_WRITE_COMPLEMENT:
        LD A,B
        CPL
        LD (HL),A
        XOR (HL)
        JP Z,DIAG_RAM_REVERSE_SCAN
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,DIAG_RAM_RECORD_COMPLEMENT_ODD
        OR D
        LD D,A
        JP DIAG_RAM_REVERSE_NEXT

DIAG_RAM_RECORD_COMPLEMENT_ODD:
        OR E
        LD E,A

DIAG_RAM_REVERSE_NEXT:
        JP DIAG_RAM_REVERSE_SCAN
; Forward cleanup sweep of RAM pattern.

DIAG_RAM_FINAL_SCAN:
        OUT ($02),A
        INC HL
        LD A,H
        CP $40
        JP Z,DIAG_TEST_RESULT
        LD A,B
        CPL
        XOR (HL)
        JP Z,DIAG_RAM_CLEAR_NEXT
        LD C,A
        LD A,L
        AND $01
        LD A,C
        JP NZ,DIAG_RAM_RECORD_FINAL_ODD
        OR D
        LD D,A
        JP DIAG_RAM_CLEAR_NEXT

DIAG_RAM_RECORD_FINAL_ODD:
        OR E
        LD E,A

DIAG_RAM_CLEAR_NEXT:
        XOR A
        LD (HL),A
        JP DIAG_RAM_FINAL_SCAN
; Determine whether a memory bit failed and format error output.

DIAG_TEST_RESULT:
        LD A,B
        RLCA
        LD B,A
        JP NC,DIAG_RAM_PASS_BEGIN
        LD A,D
        OR E
        JP Z,DIAG_ROM_CHECKSUM
        EX DE,HL
        LD SP,HL
        LD DE,$2000
        LD B,$00

DIAG_RAM_ERROR_LINE:
        LD HL,$0000
        ADD HL,SP
        LD C,$10

DIAG_RAM_ERROR_PIXEL:
        XOR A
        ADD HL,HL
        JP C,DIAG_RAM_ERROR_WRITE
        CPL

DIAG_RAM_ERROR_WRITE:
        LD (DE),A
        INC DE
        LD A,$18
        LD (DE),A
        INC DE
        DEC C
        JP NZ,DIAG_RAM_ERROR_PIXEL
        DEC B
        JP NZ,DIAG_RAM_ERROR_LINE
        JP DIAG_FAILURE_HALT
; Initialize stack and checksum passes across four 1 KB ROM banks.

DIAG_ROM_CHECKSUM:
        LD SP,$2400
        LD HL,$280C
        PUSH HL
        LD HL,$0000
        LD DE,$0193
; Run one ROM device checksum and fault-report iteration.

DIAG_ROM_BANK_LOOP:
        LD BC,$0400
        XOR A
; Accumulate bytes, output progress to port 02.

DIAG_ROM_SUM_LOOP:
        ADD A,(HL)
        OUT ($02),A
        INC HL
        DEC C
        JP NZ,DIAG_ROM_SUM_LOOP
        DEC B
        JP NZ,DIAG_ROM_SUM_LOOP
        INC A
        JP Z,DIAG_ROM_NEXT_DEVICE
        LD A,(DE)
        EX (SP),HL
        EX DE,HL
        PUSH BC
        CALL ADVANCE_DISPLAY_CURSOR
        POP BC
        EX DE,HL
        EX (SP),HL

DIAG_ROM_NEXT_DEVICE:
        INC DE
        LD A,H
        CP $10
        JP NZ,DIAG_ROM_BANK_LOOP
        POP HL
        LD A,L
        CP $0C
        JP Z,RESET_ENTRY
; Failure loop: repeated output to port 02.

DIAG_FAILURE_HALT:
        OUT ($02),A
        JP DIAG_FAILURE_HALT
        DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$48,$47,$46 ; ROM $018A  pixels ........ ........ ........ ........ ........ ........ ........ ........ ........ .#..#... .#...### .#...##.
        DB $45,$3C,$7E,$66,$66,$66,$66,$66,$66,$7E,$3C,$18 ; ROM $0196  pixels .#...#.# ..####.. .######. .##..##. .##..##. .##..##. .##..##. .##..##. .##..##. .######. ..####.. ...##...
        DB $1C,$18,$18,$18,$18,$18,$18,$3C,$3C,$3C,$7E,$66 ; ROM $01A2  pixels ...###.. ...##... ...##... ...##... ...##... ...##... ...##... ..####.. ..####.. ..####.. .######. .##..##.
        DB $60,$7C,$3E,$06,$06,$7E,$7E,$3C,$7E,$66,$60,$38 ; ROM $01AE  pixels .##..... .#####.. ..#####. .....##. .....##. .######. .######. ..####.. .######. .##..##. .##..... ..###...
        DB $78,$60,$66,$7E,$3C,$66,$66,$66,$66,$7E,$7E,$60 ; ROM $01BA  pixels .####... .##..... .##..##. .######. ..####.. .##..##. .##..##. .##..##. .##..##. .######. .######. .##.....
        DB $60,$60,$60,$3E,$3E,$06,$06,$3E,$7E,$60,$66,$7E ; ROM $01C6  pixels .##..... .##..... .##..... ..#####. ..#####. .....##. .....##. ..#####. .######. .##..... .##..##. .######.
        DB $3C,$3C,$3E,$06,$06,$3E,$7E,$66,$66,$7E,$3C,$7E ; ROM $01D2  pixels ..####.. ..####.. ..#####. .....##. .....##. ..#####. .######. .##..##. .##..##. .######. ..####.. .######.
        DB $7E,$60,$70,$30,$38,$18,$1C,$0C,$0C,$3C,$7E,$66 ; ROM $01DE  pixels .######. .##..... .###.... ..##.... ..###... ...##... ...###.. ....##.. ....##.. ..####.. .######. .##..##.
        DB $66,$3C,$7E,$66,$66,$7E,$3C,$3C,$7E,$66,$66,$7E ; ROM $01EA  pixels .##..##. ..####.. .######. .##..##. .##..##. .######. ..####.. ..####.. .######. .##..##. .##..##. .######.
        DB $7C,$60,$60,$7C,$3C,$00,$FF,$81,$81,$81,$81,$81 ; ROM $01F6  pixels .#####.. .##..... .##..... .#####.. ..####.. ........ ######## #......# #......# #......# #......# #......#
        DB $81,$FF,$00,$00,$FF,$81,$BD,$A5,$A5,$BD,$81,$FF ; ROM $0202  pixels #......# ######## ........ ........ ######## #......# #.####.# #.#..#.# #.#..#.# #.####.# #......# ########
        DB $00,$00,$FF,$D5,$AB,$D5,$AB,$D5,$AB,$FF,$00,$00 ; ROM $020E  pixels ........ ........ ######## ##.#.#.# #.#.#.## ##.#.#.# #.#.#.## ##.#.#.# #.#.#.## ######## ........ ........
        DB $FF,$E7,$E7,$99,$99,$E7,$E7,$FF,$00,$FF,$FF,$FF ; ROM $021A  pixels ######## ###..### ###..### #..##..# #..##..# ###..### ###..### ######## ........ ######## ######## ########
        DB $FF,$FF,$FF,$FF,$FF,$FF,$FF,$18,$18,$18,$18,$18 ; ROM $0226  pixels ######## ######## ######## ######## ######## ######## ######## ...##... ...##... ...##... ...##... ...##...
        DB $18,$00,$00,$18,$18,$00,$00,$00,$00,$00,$00,$00 ; ROM $0232  pixels ...##... ........ ........ ...##... ...##... ........ ........ ........ ........ ........ ........ ........
        DB $00,$00,$00,$18,$3C,$7E,$66,$66,$66,$7E,$7E,$66 ; ROM $023E  pixels ........ ........ ........ ...##... ..####.. .######. .##..##. .##..##. .##..##. .######. .######. .##..##.
        DB $66,$3E,$7E,$66,$66,$3E,$7E,$66,$66,$7E,$3E,$3C ; ROM $024A  pixels .##..##. ..#####. .######. .##..##. .##..##. ..#####. .######. .##..##. .##..##. .######. ..#####. ..####..
        DB $7E,$66,$06,$06,$06,$06,$66,$7E,$3C,$3E,$7E,$66 ; ROM $0256  pixels .######. .##..##. .....##. .....##. .....##. .....##. .##..##. .######. ..####.. ..#####. .######. .##..##.
        DB $66,$66,$66,$66,$66,$7E,$3E,$7E,$7E,$06,$06,$3E ; ROM $0262  pixels .##..##. .##..##. .##..##. .##..##. .##..##. .######. ..#####. .######. .######. .....##. .....##. ..#####.
        DB $3E,$06,$06,$7E,$7E,$7E,$7E,$06,$06,$3E,$3E,$06 ; ROM $026E  pixels ..#####. .....##. .....##. .######. .######. .######. .######. .....##. .....##. ..#####. ..#####. .....##.
        DB $06,$06,$06,$3C,$7E,$66,$06,$06,$76,$76,$66,$7E ; ROM $027A  pixels .....##. .....##. .....##. ..####.. .######. .##..##. .....##. .....##. .###.##. .###.##. .##..##. .######.
        DB $3C,$66,$66,$66,$66,$7E,$7E,$66,$66,$66,$66,$3C ; ROM $0286  pixels ..####.. .##..##. .##..##. .##..##. .##..##. .######. .######. .##..##. .##..##. .##..##. .##..##. ..####..
        DB $3C,$18,$18,$18,$18,$18,$18,$3C,$3C,$60,$60,$60 ; ROM $0292  pixels ..####.. ...##... ...##... ...##... ...##... ...##... ...##... ..####.. ..####.. .##..... .##..... .##.....
        DB $60,$60,$60,$60,$66,$7E,$3C,$66,$66,$76,$3E,$1E ; ROM $029E  pixels .##..... .##..... .##..... .##..... .##..##. .######. ..####.. .##..##. .##..##. .###.##. ..#####. ...####.
        DB $1E,$3E,$76,$66,$66,$06,$06,$06,$06,$06,$06,$06 ; ROM $02AA  pixels ...####. ..#####. .###.##. .##..##. .##..##. .....##. .....##. .....##. .....##. .....##. .....##. .....##.
        DB $06,$7E,$7E,$C3,$C3,$E7,$E7,$FF,$FF,$DB,$C3,$C3 ; ROM $02B6  pixels .....##. .######. .######. ##....## ##....## ###..### ###..### ######## ######## ##.##.## ##....## ##....##
        DB $C3,$66,$66,$6E,$6E,$7E,$7E,$76,$76,$66,$66,$3C ; ROM $02C2  pixels ##....## .##..##. .##..##. .##.###. .##.###. .######. .######. .###.##. .###.##. .##..##. .##..##. ..####..
        DB $7E,$66,$66,$66,$66,$66,$66,$7E,$3C,$3E,$7E,$66 ; ROM $02CE  pixels .######. .##..##. .##..##. .##..##. .##..##. .##..##. .##..##. .######. ..####.. ..#####. .######. .##..##.
        DB $66,$7E,$3E,$06,$06,$06,$06,$3C,$7E,$66,$66,$66 ; ROM $02DA  pixels .##..##. .######. ..#####. .....##. .....##. .....##. .....##. ..####.. .######. .##..##. .##..##. .##..##.
        DB $66,$66,$66,$7E,$5C,$3E,$7E,$66,$66,$7E,$3E,$76 ; ROM $02E6  pixels .##..##. .##..##. .##..##. .######. .#.###.. ..#####. .######. .##..##. .##..##. .######. ..#####. .###.##.
        DB $66,$66,$66,$3C,$7E,$66,$06,$3E,$7C,$60,$66,$7E ; ROM $02F2  pixels .##..##. .##..##. .##..##. ..####.. .######. .##..##. .....##. ..#####. .#####.. .##..... .##..##. .######.
        DB $3C,$7E,$7E,$18,$18,$18,$18,$18,$18,$18,$18,$66 ; ROM $02FE  pixels ..####.. .######. .######. ...##... ...##... ...##... ...##... ...##... ...##... ...##... ...##... .##..##.
        DB $66,$66,$66,$66,$66,$66,$66,$7E,$3C,$66,$66,$66 ; ROM $030A 8-bit glyph and tile bitmap bytes
        DB $66,$66,$7E,$3C,$3C,$18,$18,$C3,$C3,$C3,$DB,$FF ; ROM $0316 8-bit glyph and tile bitmap bytes
        DB $FF,$E7,$E7,$C3,$C3,$66,$66,$7E,$3C,$18,$18,$3C ; ROM $0322 8-bit glyph and tile bitmap bytes
        DB $7E,$66,$66,$66,$66,$7E,$3C,$18,$18,$18,$18,$18 ; ROM $032E 8-bit glyph and tile bitmap bytes
        DB $18,$7E,$7E,$60,$70,$38,$1C,$0E,$06,$7E,$7E,$00 ; ROM $033A 8-bit glyph and tile bitmap bytes
        DB $FF,$EF,$E7,$EF,$EF,$EF,$C7,$FF,$00,$00,$FF,$C3 ; ROM $0346 8-bit glyph and tile bitmap bytes
        DB $DB,$DF,$C3,$FB,$C3,$FF,$00,$00,$FF,$C3,$DF,$E7 ; ROM $0352 8-bit glyph and tile bitmap bytes
        DB $DF,$DF,$C3,$FF,$00,$00,$FF,$DB,$DB,$C3,$DF,$DF ; ROM $035E 8-bit glyph and tile bitmap bytes
        DB $DF,$FF,$00,$FF,$FF,$FF,$E8,$EA,$E8,$EE,$8E,$FF ; ROM $036A 8-bit glyph and tile bitmap bytes
        DB $FF,$FF,$FF,$FF,$A8,$AA,$88,$DA,$DA,$FF,$FF,$FF ; ROM $0376 8-bit glyph and tile bitmap bytes
        DB $FF,$FF,$C8,$AE,$CC,$AE,$A8,$FF,$FF,$FF,$FF,$FF ; ROM $0382 8-bit glyph and tile bitmap bytes
        DB $47,$57,$57,$57,$47,$FF,$FF,$FF,$FF,$FF,$17,$D6 ; ROM $038E 8-bit glyph and tile bitmap bytes
        DB $95,$D3,$17,$FF,$FF,$FF,$FF,$FF,$47,$6F,$6F,$6F ; ROM $039A 8-bit glyph and tile bitmap bytes
        DB $EF,$FF,$FF,$FF,$FF,$FF,$17,$57,$55,$55,$18,$FF ; ROM $03A6 8-bit glyph and tile bitmap bytes
        DB $FF,$FF,$FF,$FF,$1F,$BF,$BF,$BF,$BF,$FF,$FF,$FF ; ROM $03B2 8-bit glyph and tile bitmap bytes
        DB $FF,$FF,$95,$55,$91,$55,$55,$FF,$FF,$FF,$FF,$FF ; ROM $03BE 8-bit glyph and tile bitmap bytes
        DB $11,$DD,$99,$DD,$11,$FF,$FF,$FF,$FF,$FF,$11,$5D ; ROM $03CA 8-bit glyph and tile bitmap bytes
        DB $59,$5D,$1D,$FF,$FF,$FF,$FF,$FF,$95,$55,$95,$55 ; ROM $03D6 8-bit glyph and tile bitmap bytes
        DB $51,$FF,$FF ; ROM $03E2 8-bit glyph and tile bitmap bytes
; Process high-nibble pixel data and call display cursor utility.

ADVANCE_GLYPH_NIBBLE:
        LD A,(HL)
        AND $F0
        JP NZ,FLOW_03F4
        LD A,$40
        CALL ADVANCE_DISPLAY_CURSOR
        JP FLOW_03FB
        DB $7E ; ROM $03F3 preserved non-executable data / unresolved structure

FLOW_03F4:
        RLCA
        RLCA
        RLCA
        RLCA
        CALL DRAW_GLYPH_NIBBLE

FLOW_03FB:
        LD A,(HL)
; Low-nibble glyph-to-display drawing path.

DRAW_GLYPH_NIBBLE:
        AND $0F
        ADD A,$30
        ORG $0400
; ROM device checkmat.g — SHA-1 484ff9bfb95166ba09f34c753a7908a73de3cc7d
; Map glyph advances into 32-byte display rows.

ADVANCE_DISPLAY_CURSOR:
        AND $7F
        CP $30
        LD B,$00
        JP NC,FLOW_041D
        EX DE,HL
        LD BC,$01E0
; Advance display cursor across a 32-byte row boundary.

ADVANCE_DISPLAY_ROW:
        PUSH AF
        INC HL
        LD A,L
        AND $1F
        JP NZ,FLOW_0416
        ADD HL,BC

FLOW_0416:
        POP AF
        DEC A
        JP NZ,ADVANCE_DISPLAY_ROW
        EX DE,HL
        RET

FLOW_041D:
        PUSH HL
        PUSH DE
        CALL SUBROUTINE_043A
        LD A,($21E8)
        LD C,A

FLOW_0426:
        PUSH BC
        LD A,(DE)
        INC DE
        XOR C
        LD (HL),A
        LD BC,$0020
        ADD HL,BC
        POP BC
        DEC B
        JP NZ,FLOW_0426
        POP DE
        INC DE
        POP HL
        RET

SUBROUTINE_0438:
        LD B,$00

SUBROUTINE_043A:
        SUB $30
        LD C,A
        LD H,B
        LD L,C
        ADD HL,HL
        ADD HL,HL
        ADD HL,HL
        ADD HL,BC
        ADD HL,BC
        LD BC,$0197
        ADD HL,BC
        LD B,$0A
        EX DE,HL
        RET

SUBROUTINE_044C:
        AND $7F
        PUSH HL
        CP $30
        JP NC,FLOW_045B
        LD L,A
        LD H,$00
        ADD HL,DE
        EX DE,HL
        POP HL
        RET

FLOW_045B:
        PUSH DE
        CALL SUBROUTINE_0438

FLOW_045F:
        PUSH BC
        LD A,(DE)
        INC DE
        PUSH DE
        PUSH HL
        LD HL,$21E3
        LD BC,$0004

FLOW_046A:
        LD E,A
        LD D,B
        RLCA
        JP NC,FLOW_0472
        LD D,$F0

FLOW_0472:
        RLCA
        LD A,B
        JP NC,FLOW_0479
        LD A,$0F

FLOW_0479:
        OR D
        LD (HL),A
        DEC HL
        LD A,E
        RLCA
        RLCA
        DEC C
        JP NZ,FLOW_046A
        EX DE,HL
        INC DE
        POP HL
        LD C,$04

FLOW_0488:
        PUSH DE
        PUSH HL
        LD B,$04

FLOW_048C:
        LD A,(DE)
        INC DE
        LD (HL),A
        INC HL
        DEC B
        JP NZ,FLOW_048C
        POP HL
        LD DE,$0020
        ADD HL,DE
        POP DE
        DEC C
        JP NZ,FLOW_0488
        POP DE
        POP BC
        DEC B
        JP NZ,FLOW_045F
        POP DE
        INC DE
        INC DE
        INC DE
        INC DE
        POP HL
        RET
        DB $A3,$00,$00,$00,$00,$00,$00,$00,$00,$18,$3C,$7E ; ROM $04AB preserved non-executable data / unresolved structure
        DB $FF,$18,$18,$18,$18,$18,$18,$18,$18,$FF,$7E,$3C ; ROM $04B7 preserved non-executable data / unresolved structure
        DB $18,$08,$0C,$0E,$FF,$FF,$0E,$0C,$08,$10,$30,$70 ; ROM $04C3 preserved non-executable data / unresolved structure
        DB $FF,$FF,$70,$30,$10,$0A,$00,$00,$00,$18,$18,$00 ; ROM $04CF preserved non-executable data / unresolved structure
        DB $00,$00,$0A,$00,$00,$24,$18,$18,$24,$00,$00,$0A ; ROM $04DB preserved non-executable data / unresolved structure
        DB $00,$24,$42,$18,$18,$42,$24,$00,$14,$52,$81,$24 ; ROM $04E7 preserved non-executable data / unresolved structure
        DB $11,$88,$24,$81,$4A,$00 ; ROM $04F3 preserved non-executable data / unresolved structure
; Game initialization target after diagnostic port-02 gate.

BOOT_GAME_INIT:
        LD SP,$2400
        CALL SUBROUTINE_0D0B
        LD HL,$2000
        LD BC,$047E
        CALL SUBROUTINE_0514
        LD HL,$FFFF
        LD ($200A),HL
        LD ($200C),HL
        JP FLOW_0672

SUBROUTINE_0514:
        XOR A

FLOW_0515:
        LD (HL),A
        INC HL
        DEC C
        JP NZ,FLOW_0515
        DEC B
        JP NZ,FLOW_0515
        RET

SUBROUTINE_0520:
        OUT ($02),A
        LD HL,$2001
        LD A,(HL)
        AND A
        JP Z,FLOW_054E
        LD (HL),$00
        INC HL
        INC (HL)
        LD DE,$0FE8
        CALL SUBROUTINE_0D78
        LD A,($2006)
        AND A
        RET NZ
        LD SP,$2400
        CALL SUBROUTINE_0D0B
        LD DE,$0000

FLOW_0542:
        CALL SUBROUTINE_0DC6
        CALL SUBROUTINE_06A5

FLOW_0548:
        CALL SUBROUTINE_0520
        JP FLOW_0548

FLOW_054E:
        LD A,($2003)
        AND A
        JP NZ,FLOW_056E
        LD HL,($2004)
        LD A,(HL)
        AND A
        JP Z,FLOW_056B
        LD ($2003),A
        INC HL
        LD A,(HL)
        OUT ($01),A
        INC HL
        LD ($2004),HL
        JP FLOW_056E

FLOW_056B:
        XOR A
        OUT ($01),A

FLOW_056E:
        CALL SUBROUTINE_0D91
        LD A,($2006)
        AND A
        RET NZ
        IN A,($03)
        AND $0F
        RET Z
        LD E,$00

FLOW_057D:
        INC E
        RRCA
        JP NC,FLOW_057D
        IN A,($02)
        AND $01
        LD D,A
        LD A,E
        RLCA
        OR D
        LD HL,$0E10
        CALL SUBROUTINE_0C91
        LD D,A
        LD HL,$2002
        LD A,(HL)
        SUB D
        RET M
        LD (HL),A
        LD A,E
        CP $01
        JP NZ,FLOW_05A7
        LD ($2009),A
        LD A,$04
        LD E,A
        JP FLOW_05AA

FLOW_05A7:
        LD ($2009),A

FLOW_05AA:
        LD ($2007),A
        LD A,E
        LD HL,$0FB8
        CALL SUBROUTINE_0C9C
        LD ($200E),HL
        LD A,$01
        LD ($2006),A
        LD SP,$2400
        LD HL,$2027
        LD BC,$0296
        CALL SUBROUTINE_0514
        IN A,($02)
        RRCA
        RRCA
        AND $03
        ADD A,$02
        LD ($2008),A
        LD A,$01
        LD ($2010),A
        LD HL,$202D
        LD ($202B),HL

FLOW_05DE:
        CALL SUBROUTINE_06BC
        LD HL,$2010
        RST $20
        LD HL,$2008
        DEC (HL)
        JP NZ,FLOW_05DE
        XOR A
        LD ($2006),A
        LD HL,$2027
        LD A,($2007)
        LD B,A
        LD DE,$0000
        LD C,D

FLOW_05FB:
        LD A,(HL)
        INC HL
        CP C
        JP Z,FLOW_0608
        JP C,FLOW_0609
        LD C,A
        LD E,B
        LD D,$FF

FLOW_0608:
        INC D

FLOW_0609:
        DEC B
        JP NZ,FLOW_05FB
        LD A,D
        AND A
        JP Z,FLOW_0621
        LD DE,$0104
        CALL SUBROUTINE_0DB8
        LD DE,$0305
        CALL SUBROUTINE_0DB8
        JP FLOW_0647

FLOW_0621:
        LD HL,$0E3C
        CALL SUBROUTINE_0DE8
        JP (HL)
; Selected when input port $02 language bits choose language 0; four-way native jump.

LANGUAGE0_INTRO_RENDER:
        PUSH DE
        LD DE,$2A41
        LD HL,$0E54
        CALL FLOW_0DBB
        INC DE
        INC DE
        POP BC
        LD A,($2007)
        SUB C
        ADD A,$31
        CALL SUBROUTINE_044C
        LD DE,$3448
        LD HL,$0E5A
        CALL FLOW_0DBB

FLOW_0647:
        LD A,$FF
        RST $18
        CALL SUBROUTINE_069C
        LD DE,$0106
        CALL SUBROUTINE_0DB8
        LD DE,$0307
        CALL SUBROUTINE_0DB8
        LD DE,$0FE5
        CALL SUBROUTINE_0D73
        CALL SUBROUTINE_0DF2
        LD A,($2002)
        AND A
        JP Z,FLOW_0672
        CALL SUBROUTINE_0D0B
        LD DE,$0001
        JP FLOW_0542

FLOW_0672:
        CALL SUBROUTINE_069C
        LD DE,$0108
        CALL SUBROUTINE_0DB8
        LD DE,$0309
        CALL SUBROUTINE_0DB8
        LD A,$78
        RST $18
        CALL SUBROUTINE_069C
        LD DE,$010A
        CALL SUBROUTINE_0DB8
        LD DE,$030B
        CALL SUBROUTINE_0DB8
        LD A,$78
        RST $18
        CALL SUBROUTINE_06D5
        JP FLOW_0672

SUBROUTINE_069C:
        LD DE,$4000
        LD HL,$00C6
        JP SUBROUTINE_0D11

SUBROUTINE_06A5:
        LD DE,$0203
        IN A,($02)
        AND $01
        JP NZ,SUBROUTINE_0DC6
        LD A,($2002)
        CP $02
        JP NC,SUBROUTINE_0DC6
        LD E,$02
        JP SUBROUTINE_0DC6

SUBROUTINE_06BC:
        CALL SUBROUTINE_07F6
        LD (HL),$FF
        CALL SUBROUTINE_07F6
        LD (HL),$AA
        CALL SUBROUTINE_07F6
        LD (HL),$FF
        CALL SUBROUTINE_07F6
        LD A,($2010)
        LD (HL),A
        JP FLOW_071A

SUBROUTINE_06D5:
        LD A,($2007)
        AND A
        RET Z
        LD B,$03

FLOW_06DC:
        CALL SUBROUTINE_07F6
        EX DE,HL
        LD A,(DE)
        INC A
        JP NZ,FLOW_06F6
        CALL SUBROUTINE_07F6
        LD A,(HL)
        CP $AA
        JP NZ,FLOW_06F6
        CALL SUBROUTINE_07F6
        LD A,(HL)
        INC A
        JP Z,FLOW_0708

FLOW_06F6:
        EX DE,HL
        LD ($202B),HL
        PUSH BC
        CALL SUBROUTINE_0520
        POP BC
        DEC C
        JP NZ,FLOW_06DC
        DEC B
        JP NZ,FLOW_06DC
        RET

FLOW_0708:
        CALL SUBROUTINE_07F6
        LD A,($2007)
        CP (HL)
        JP C,FLOW_06F6
        LD A,(HL)
        AND A
        JP Z,FLOW_06F6
        LD ($2010),A

FLOW_071A:
        CALL SUBROUTINE_0995
        LD A,($2010)
        LD ($2011),A
        LD A,($2007)
        LD ($2012),A
        LD A,($2006)
        AND A
        JP Z,FLOW_0756
        LD DE,$0FDC
        CALL SUBROUTINE_0D73
        LD HL,$2017
        LD (HL),$03

FLOW_073B:
        LD A,(HL)
        ADD A,$30
        LD DE,$2F8E
        CALL SUBROUTINE_044C
        LD A,$1E
        RST $18
        LD HL,$2017
        DEC (HL)
        JP NZ,FLOW_073B
        LD DE,$2F8E
        LD A,$40
        CALL SUBROUTINE_044C

FLOW_0756:
        CALL SUBROUTINE_0AEE
        LD A,($2006)
        AND A
        JP Z,FLOW_076B
        LD A,($2009)
        DEC A
        JP NZ,FLOW_0770
        LD A,($21C0)
        AND A

FLOW_076B:
        LD A,$02
        JP Z,FLOW_0776

FLOW_0770:
        LD HL,$2012
        LD A,$0B
        SUB (HL)

FLOW_0776:
        LD ($21BF),A

FLOW_0779:
        LD HL,$0FA0
        RST $28
        LD A,(HL)
        AND A
        JP NZ,FLOW_0789
        LD HL,$2011
        RST $20
        JP FLOW_0779

FLOW_0789:
        PUSH HL
        CALL SUBROUTINE_0B3C
        AND A
        JP NZ,FLOW_0796
        LD A,$04
        CALL SUBROUTINE_0CB4

FLOW_0796:
        PUSH HL
        CALL SUBROUTINE_07B3
        POP HL
        LD (HL),A
        POP HL
        CALL SUBROUTINE_080F
        LD A,($2012)
        CP $02
        JP NC,FLOW_07AC
        LD A,$78
        RST $18
        RET

FLOW_07AC:
        LD HL,$2011
        RST $20
        JP FLOW_0756

SUBROUTINE_07B3:
        LD B,A
        LD A,($2006)
        AND A
        JP Z,FLOW_07D2
        CALL SUBROUTINE_07E3
        JP P,FLOW_07C3
        LD (HL),$00

FLOW_07C3:
        LD A,B
        DEC A

FLOW_07C5:
        DEC C
        JP M,FLOW_07CE
        RLCA
        RLCA
        JP FLOW_07C5

FLOW_07CE:
        OR (HL)
        LD (HL),A
        LD A,B
        RET

FLOW_07D2:
        CALL SUBROUTINE_07E3
        LD A,(HL)

FLOW_07D6:
        DEC C
        JP M,FLOW_07DF
        RRCA
        RRCA
        JP FLOW_07D6

FLOW_07DF:
        AND $03
        INC A
        RET

SUBROUTINE_07E3:
        LD HL,$21BD
        DEC (HL)
        JP P,FLOW_07EC
        LD (HL),$03

FLOW_07EC:
        LD C,(HL)
        PUSH AF
        CALL M,SUBROUTINE_07F6
        POP AF
        LD HL,($202B)
        RET

SUBROUTINE_07F6:
        LD HL,($202B)
        INC HL
        PUSH AF
        LD A,H
        CP $21
        DB $C2,$0A ; ROM $07FE preserved non-executable data / unresolved structure

        ORG $0800
; ROM device checkmat.f — SHA-1 39e0cf502735819a7e1d933e3686945fcfae21af
        DB $08 ; ROM $0800 preserved non-executable data / unresolved structure
        LD A,L
        CP $BD
        JP NZ,FLOW_080A
        LD HL,$202D

FLOW_080A:
        LD ($202B),HL
        POP AF
        RET

SUBROUTINE_080F:
        LD ($2013),HL
        LD BC,$0006
        ADD HL,BC
        PUSH HL
        PUSH HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        LD A,C
        OR B
        JP Z,FLOW_0826
        LD HL,$0F5C
        CALL SUBROUTINE_0D33

FLOW_0826:
        POP HL
        DEC HL
        LD B,(HL)
        DEC HL
        LD C,(HL)
        EX (SP),HL
        LD (HL),C
        INC HL
        LD (HL),B
        PUSH BC
        LD HL,$0F54
        CALL SUBROUTINE_0D33
        LD HL,($2013)
        INC HL
        INC HL
        INC HL
        LD A,(HL)
        LD ($2018),A
        LD HL,$0FB0
        CALL SUBROUTINE_0C9C
        POP BC
        LD A,H
        ADD A,B
        LD B,A
        LD A,L
        ADD A,C
        LD C,A
        POP HL
        LD (HL),C
        INC HL
        LD (HL),B
        CALL SUBROUTINE_0C59
        JP NZ,FLOW_088C
        LD A,($2011)
        CALL SUBROUTINE_0C3B
        LD A,($2018)
        LD HL,$0F64
        CALL SUBROUTINE_0C9C
        CALL SUBROUTINE_0D34
        LD A,($2011)
        DEC A
        AND $03
        RLCA
        RLCA
        LD B,A
        LD A,($2018)
        DEC A
        OR B
        RLCA
        RLCA
        RLCA
        RLCA
        OR $09
        LD B,A
        LD C,$05
        JP SUBROUTINE_0D5B
        DB $2A,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $0883 preserved non-executable data / unresolved structure

FLOW_088C:
        CALL SUBROUTINE_0C83
        LD ($2015),HL
        LD BC,$0A28
        CALL SUBROUTINE_0D5B
        LD HL,$0E44
        CALL SUBROUTINE_0DE8
        JP (HL)
; Selected from second language dispatch table; round and scoreboard logic.

LANGUAGE0_ROUND_SETUP:
        LD A,$FF
        LD ($21E8),A
        LD DE,$3E61
        LD HL,$0E54
        CALL SUBROUTINE_0DC9
        INC DE
        LD HL,$0EFF
        RST $28
        CALL SUBROUTINE_0DC9
        INC DE
        CALL SUBROUTINE_0D91
        AND $03
        LD HL,$0F18
        CALL SUBROUTINE_0C9C
        CALL SUBROUTINE_0DC9
        XOR A
        LD ($21E8),A
        LD HL,($2015)
        LD DE,$21E0
        CALL $0D4A
        LD DE,$04D4

ROUND_WINNER_TEXT_LOOP:
        LD A,(DE)
        INC DE
        AND A
        JP Z,ROUND_WINNER_TEXT_END
        PUSH AF
        LD HL,($2015)
        CALL SUBROUTINE_0D39
        POP AF
        RST $18
        JP ROUND_WINNER_TEXT_LOOP

ROUND_WINNER_TEXT_END:
        LD HL,($2015)
        LD DE,$21E0
        CALL SUBROUTINE_0D39
        LD HL,($2013)
        LD (HL),$00
        LD A,($2006)
        AND A
        JP Z,ROUND_PLAYER_COUNT_LOOP
        LD A,($2011)
        PUSH AF
        LD A,($2007)
        LD ($2011),A

ROUND_SCORE_UPDATE_LOOP:
        LD HL,$0FA0
        RST $28
        LD A,(HL)
        AND A
        JP Z,ROUND_SCORE_UPDATE_DONE
        LD HL,$2026
        CALL SUBROUTINE_0C8E
        LD A,(HL)
        INC A
        DAA
        LD (HL),A
        CALL SUBROUTINE_0CCA

ROUND_SCORE_UPDATE_DONE:
        LD HL,$2011
        DEC (HL)
        JP NZ,ROUND_SCORE_UPDATE_LOOP
        POP AF
        LD ($2011),A

ROUND_PLAYER_COUNT_LOOP:
        LD HL,$2012
        DEC (HL)
        LD B,$19

ROUND_PLAYER_COUNT_INNER:
        LD C,$1F

ROUND_PLAYER_COUNT_STEP:
        LD A,($2011)
        LD E,A
        CALL SUBROUTINE_0C59
        CP E
        JP NZ,ROUND_PLAYER_COUNT_MISMATCH
        XOR A
        CALL SUBROUTINE_0C3B
        CALL SUBROUTINE_0C83
        PUSH BC
        LD B,$08
        XOR A
        CALL SUBROUTINE_0CDF
        POP BC

ROUND_PLAYER_COUNT_MISMATCH:
        DEC C
        JP P,ROUND_PLAYER_COUNT_STEP
        DEC B
        JP P,ROUND_PLAYER_COUNT_INNER
        LD A,$04
        LD ($2017),A

ROUND_END_FRAME_LOOP:
        LD A,($2012)
        LD ($2019),A
        LD ($201A),A

ROUND_SHOW_WINNER_LOOP:
        LD HL,$201A
        RST $20
        LD A,(HL)
        LD HL,$0FA0
        CALL SUBROUTINE_0C9C
        LD A,(HL)
        AND A
        JP Z,ROUND_SHOW_WINNER_LOOP
        LD HL,($200E)
        LD A,($201A)
        CALL SUBROUTINE_0C9C
        CALL SUBROUTINE_0CE9
        LD HL,$2019
        DEC (HL)
        JP NZ,ROUND_SHOW_WINNER_LOOP
        LD A,$1E
        RST $18
        LD HL,$2017
        DEC (HL)
        JP NZ,ROUND_END_FRAME_LOOP
        LD DE,$4000
        LD HL,$FF0E
        CALL SUBROUTINE_0D11
        RET

SUBROUTINE_0995:
        LD DE,$4000
        LD HL,$FF0E
        CALL SUBROUTINE_0D11
        LD DE,$3E40
        LD HL,$00B8
        CALL SUBROUTINE_0D11
        LD DE,$2740
        LD HL,$FF1A
        CALL SUBROUTINE_0D11
        LD HL,$2740
        LD B,$B8
        CALL SUBROUTINE_0CDD
        LD HL,$275F
        LD B,$B8
        CALL SUBROUTINE_0CDD
        LD HL,$21BD
        LD BC,$02C1
        CALL SUBROUTINE_0514
        LD C,$1F
        LD E,$0F

FLOW_09CD:
        LD B,$00
        LD A,E
        CALL SUBROUTINE_0C3B
        LD B,$18
        LD A,E
        CALL SUBROUTINE_0C3B
        DEC C
        JP P,FLOW_09CD
        LD B,$18

FLOW_09DF:
        LD C,$00
        LD A,E
        CALL SUBROUTINE_0C3B
        LD C,$1F
        LD A,E
        CALL SUBROUTINE_0C3B
        DEC B
        JP P,FLOW_09DF
        LD A,($2006)
        AND A
        JP Z,FLOW_0A08
        LD A,$FF
        LD ($21E8),A
        LD HL,$2008
        LD DE,$250F
        CALL ADVANCE_GLYPH_NIBBLE
        XOR A
        LD ($21E8),A

FLOW_0A08:
        INC A
        LD ($2017),A
        LD A,($2010)
        LD ($2011),A
        LD A,($2007)

FLOW_0A15:
        PUSH AF
        LD HL,($200E)
        RST $28
        PUSH HL
        PUSH HL
        CALL SUBROUTINE_0CE9
        LD HL,$0F6C
        RST $28
        EX (SP),HL
        LD BC,$0161
        ADD HL,BC
        EX DE,HL
        POP HL
        CALL SUBROUTINE_0DC9
        CALL SUBROUTINE_0CCA
        LD HL,$0F80
        RST $28
        POP DE
        INC DE
        CALL SUBROUTINE_0DC9
        LD A,($2017)
        LD HL,$0FC0
        CALL SUBROUTINE_0C9C
        EX DE,HL
        LD HL,$0FA0
        RST $28
        LD (HL),$01
        INC HL
        LD (HL),$01
        LD A,($2009)
        CP $01
        JP NZ,FLOW_0A55
        DEC (HL)

FLOW_0A55:
        INC HL
        INC HL
        INC HL
        LD (HL),E
        INC HL
        LD (HL),D
        INC HL
        LD B,D
        LD C,E
        PUSH HL
        LD HL,$0FA8
        RST $28
        EX DE,HL
        POP HL
        LD (HL),E
        INC HL
        LD (HL),D
        LD A,($2011)
        CALL SUBROUTINE_0C3B
        LD HL,$2017
        INC (HL)
        LD HL,$2011
        RST $20
        POP AF
        DEC A
        JP NZ,FLOW_0A15
        LD A,($2007)
        LD ($2012),A

FLOW_0A81:
        LD A,($2007)
        LD ($2017),A

FLOW_0A87:
        LD HL,$0FA0
        RST $28
        LD DE,$0004
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        INC HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        LD A,B
        OR C
        JP Z,FLOW_0AD4
        LD A,B
        CP D
        JP NZ,FLOW_0AB0
        LD A,C
        XOR E
        JP NZ,FLOW_0AB0
        LD (HL),A
        DEC HL
        LD (HL),A
        LD HL,$2012
        DEC (HL)
        JP NZ,FLOW_0AD4
        RET

FLOW_0AB0:
        PUSH HL
        CALL SUBROUTINE_0C83
        PUSH DE
        PUSH BC
        LD B,$08
        XOR A
        CALL SUBROUTINE_0CDF
        POP BC
        POP DE
        LD A,B
        CP D
        CALL SUBROUTINE_0AE5
        LD B,A
        LD A,C
        CP E
        CALL SUBROUTINE_0AE5
        LD C,A
        POP HL
        LD (HL),B
        DEC HL
        LD (HL),C
        LD HL,$0F54
        CALL SUBROUTINE_0D33

FLOW_0AD4:
        LD HL,$2011
        RST $20
        LD HL,$2017
        DEC (HL)
        JP NZ,FLOW_0A87
        LD A,$06
        RST $18
        JP FLOW_0A81

SUBROUTINE_0AE5:
        RET Z
        JP C,FLOW_0AEB
        DEC A
        RET

FLOW_0AEB:
        INC A
        RET
        DB $C9 ; ROM $0AED preserved non-executable data / unresolved structure

SUBROUTINE_0AEE:
        LD A,($2011)
        LD ($201A),A

FLOW_0AF4:
        CALL SUBROUTINE_0520
        LD A,($21BF)
        AND A
        RET Z
        LD A,($2006)
        AND A
        JP Z,FLOW_0AF4
        LD A,($201A)
        LD HL,$0FA0
        CALL SUBROUTINE_0C9C
        LD A,(HL)
        AND A
        JP Z,FLOW_0B35
        PUSH HL
        LD BC,$0006
        ADD HL,BC
        LD A,(HL)
        INC HL
        OR (HL)
        POP HL
        JP Z,FLOW_0B35
        INC HL
        LD A,(HL)
        AND A
        JP Z,FLOW_0B35
        DEC HL
        CALL SUBROUTINE_0B3C
        LD HL,$0F64
        CALL SUBROUTINE_0C9C
        PUSH HL
        CALL SUBROUTINE_0C83
        POP DE
        CALL SUBROUTINE_0D39

FLOW_0B35:
        LD HL,$201A
        RST $20
        JP FLOW_0AF4

SUBROUTINE_0B3C:
        INC HL
        LD D,(HL)
        INC HL
        PUSH HL
        INC HL
        LD E,(HL)
        INC HL
        LD C,(HL)
        INC HL
        LD B,(HL)
        LD A,D
        AND A
        JP NZ,FLOW_0BAB
        XOR A
        LD ($201B),A
        LD ($2021),A
        LD HL,$21E9
        INC (HL)
        PUSH DE
        LD E,$05
        CALL SUBROUTINE_0BCF
        POP DE
        LD HL,$21E9
        DEC (HL)
        LD HL,$2021
        LD A,(HL)
        AND A
        JP Z,FLOW_0B96
        LD HL,$21E9
        PUSH AF
        CALL SUBROUTINE_0C8E
        POP AF
        DEC (HL)
        JP P,FLOW_0B80
        CALL SUBROUTINE_0D91
        AND $0F
        ADD A,$0A
        LD (HL),A
        JP FLOW_0B8F

FLOW_0B80:
        LD HL,$2021
        LD D,A
        LD A,E
        LD E,D

FLOW_0B86:
        INC HL
        CP (HL)
        JP Z,FLOW_0BA7
        DEC D
        JP NZ,FLOW_0B86

FLOW_0B8F:
        LD HL,$2021
        LD A,(HL)
        JP FLOW_0B9E

FLOW_0B96:
        LD HL,$201B
        LD A,(HL)
        AND A
        JP Z,FLOW_0BA7

FLOW_0B9E:
        CALL SUBROUTINE_0CB4
        CALL SUBROUTINE_0C91
        POP HL
        INC HL
        RET

FLOW_0BA7:
        POP HL
        INC HL
        LD A,(HL)
        RET

FLOW_0BAB:
        CALL SUBROUTINE_0BCD
        POP HL
        LD A,(HL)
        INC HL
        AND D
        LD D,A
        LD A,E
        RET Z
        CP $03
        LD A,D
        JP C,FLOW_0BC4
        LD E,$00

FLOW_0BBD:
        INC E
        RRCA
        JP NC,FLOW_0BBD
        LD A,E
        RET

FLOW_0BC4:
        LD E,$09

FLOW_0BC6:
        DEC E
        RLCA
        JP NC,FLOW_0BC6
        LD A,E
        RET

SUBROUTINE_0BCD:
        LD D,$00

SUBROUTINE_0BCF:
        CALL SUBROUTINE_0BDD

SUBROUTINE_0BD2:
        INC B
        CALL SUBROUTINE_0BE8
        DEC B
        DEC B
        CALL SUBROUTINE_0BE8
        INC B
        RET

SUBROUTINE_0BDD:
        INC C
        CALL SUBROUTINE_0BE8
        DEC C
        DEC C
        CALL SUBROUTINE_0BE8
        INC C
        RET

SUBROUTINE_0BE8:
        LD A,($21E9)
        AND A
        JP NZ,FLOW_0BFD
        PUSH HL
        CALL SUBROUTINE_0C59
        LD A,D
        JP NZ,FLOW_0BF9
        OR $80

FLOW_0BF9:
        RLCA
        LD D,A
        POP HL
        RET

FLOW_0BFD:
        DEC A
        DB $C2,$35 ; ROM $0BFE preserved non-executable data / unresolved structure

        ORG $0C00
; ROM device checkmat.e — SHA-1 453f95dd31968d439339c41e625481170437eb0f
        DB $0C ; ROM $0C00 preserved non-executable data / unresolved structure
        DEC E
        CALL SUBROUTINE_0C59
        RET NZ
        LD HL,$201B
        INC (HL)
        LD A,(HL)
        CALL SUBROUTINE_0C91
        LD (HL),E
        LD HL,$21E9
        INC (HL)
        LD A,E
        LD D,$00
        CP $03
        JP C,FLOW_0C21
        CALL SUBROUTINE_0BD2
        JP FLOW_0C24

FLOW_0C21:
        CALL SUBROUTINE_0BDD

FLOW_0C24:
        LD HL,$21E9
        DEC (HL)
        LD A,D
        AND A
        RET Z
        LD HL,$2021
        INC (HL)
        LD A,(HL)
        CALL SUBROUTINE_0C91
        LD (HL),E
        RET

FLOW_0C35:
        CALL SUBROUTINE_0C59
        RET NZ
        INC D
        RET

SUBROUTINE_0C3B:
        PUSH HL
        PUSH DE
        PUSH AF
        CALL SUBROUTINE_0C6B
        LD A,(HL)
        JP C,FLOW_0C50
        AND $0F
        LD E,A
        POP AF
        RLCA
        RLCA
        RLCA
        RLCA
        JP FLOW_0C54

FLOW_0C50:
        AND $F0
        LD E,A
        POP AF

FLOW_0C54:
        OR E
        LD (HL),A
        POP DE
        POP HL
        RET

SUBROUTINE_0C59:
        PUSH HL
        PUSH DE
        CALL SUBROUTINE_0C6B
        LD A,(HL)
        JP C,FLOW_0C66
        RRCA
        RRCA
        RRCA
        RRCA

FLOW_0C66:
        AND $0F
        POP DE
        POP HL
        RET

SUBROUTINE_0C6B:
        LD A,B
        RLCA
        RLCA
        RLCA
        RLCA
        LD E,A
        AND $01
        LD D,A
        LD A,E
        AND $F0
        LD E,A
        LD A,C
        RRA
        PUSH AF
        OR E
        LD E,A
        LD HL,$21EE
        ADD HL,DE
        POP AF
        RET

SUBROUTINE_0C83:
        PUSH AF
        LD A,C
        ADD A,$40
        LD L,A
        LD A,B
        ADC A,$26
        LD H,A
        POP AF
        RET

SUBROUTINE_0C8E:
        LD A,($2011)

SUBROUTINE_0C91:
        PUSH DE
        LD E,A
        LD D,$00
        ADD HL,DE
        POP DE
        LD A,(HL)
        RET
; RST $28: table lookup indexed by RAM $2011, then shared word fetch $0C9C.

RST28_INDEXED_LOOKUP:
        LD A,($2011)

SUBROUTINE_0C9C:
        RLCA
        PUSH DE
        LD E,A
        LD D,$00
        ADD HL,DE
        LD E,(HL)
        INC HL
        LD D,(HL)
        EX DE,HL
        POP DE
        RET
; RST $20: increment modulo player count at RAM $2007.

RST20_WRAP_PLAYER_INDEX:
        LD A,($2007)
        CP (HL)
        JP Z,FLOW_0CB1
        INC (HL)
        RET

FLOW_0CB1:
        LD (HL),$01
        RET

SUBROUTINE_0CB4:
        PUSH HL
        PUSH DE
        PUSH AF
        CALL SUBROUTINE_0D91
        LD E,A
        LD D,$00
        LD H,D
        LD L,D
        POP AF

FLOW_0CC0:
        ADD HL,DE
        DEC A
        JP NZ,FLOW_0CC0
        LD A,H
        INC A
        POP DE
        POP HL
        RET

SUBROUTINE_0CCA:
        LD HL,($200E)
        RST $28
        LD BC,$0165
        ADD HL,BC
        PUSH HL
        LD HL,$2026
        CALL SUBROUTINE_0C8E
        POP DE
        JP ADVANCE_GLYPH_NIBBLE

SUBROUTINE_0CDD:
        LD A,$FF

SUBROUTINE_0CDF:
        LD DE,$0020

FLOW_0CE2:
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,FLOW_0CE2
        RET

SUBROUTINE_0CE9:
        LD DE,$0140
        ADD HL,DE
        LD DE,$0019
        LD B,$0C

FLOW_0CF2:
        LD A,(HL)
        XOR $C0
        LD (HL),A
        INC HL
        LD C,$06

FLOW_0CF9:
        LD A,(HL)
        CPL
        LD (HL),A
        INC HL
        DEC C
        JP NZ,FLOW_0CF9
        LD A,(HL)
        XOR $03
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,FLOW_0CF2
        RET

SUBROUTINE_0D0B:
        LD DE,$4000
        LD HL,$00E0

SUBROUTINE_0D11:
        LD B,H
        LD C,H
        LD A,L
        LD HL,$0000
        ADD HL,SP
        EX DE,HL
        DI
        LD SP,HL

FLOW_0D1B:
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        PUSH BC
        DEC A
        JP NZ,FLOW_0D1B
        EX DE,HL
        LD SP,HL
        EI
        RET

SUBROUTINE_0D33:
        RST $28

SUBROUTINE_0D34:
        PUSH HL
        CALL SUBROUTINE_0C83
        POP DE

SUBROUTINE_0D39:
        LD B,$08
        LD C,$20

FLOW_0D3D:
        LD A,(DE)
        INC DE
        LD (HL),A
        LD A,B
        LD B,$00
        ADD HL,BC
        DEC A
        LD B,A
        JP NZ,FLOW_0D3D
        RET
        DB $06,$08,$0E,$20,$7E,$12,$13,$78,$06,$00,$09,$47 ; ROM $0D4A preserved non-executable data / unresolved structure
        DB $05,$C2,$4E,$0D,$C9 ; ROM $0D56 preserved non-executable data / unresolved structure

SUBROUTINE_0D5B:
        LD A,($2006)
        AND A
        RET Z
        LD HL,($2004)
        LD A,(HL)
        AND A
        RET NZ
        LD A,C
        LD ($2003),A
        LD A,B
        OUT ($01),A
        RET
        DB $3A,$06,$20,$A7,$C8 ; ROM $0D6E preserved non-executable data / unresolved structure

SUBROUTINE_0D73:
        LD HL,($2004)
        LD A,(HL)
        AND A

SUBROUTINE_0D78:
        EX DE,HL
        LD ($2004),HL
        RET
; RST $18: wait while RAM $21BE countdown is nonzero, servicing $0520.

RST18_WAIT_TIMER:
        LD ($21BE),A
        PUSH BC
        PUSH DE
        PUSH HL

FLOW_0D83:
        CALL SUBROUTINE_0520
        LD A,($21BE)
        AND A
        JP NZ,FLOW_0D83
        POP HL
        POP DE
        POP BC
        RET

SUBROUTINE_0D91:
        PUSH HL
        PUSH BC
        LD HL,$200A
        LD B,$08
        LD A,(HL)

FLOW_0D99:
        RLCA
        RLCA
        RLCA
        XOR (HL)
        RLA
        RLA
        LD HL,$200A
        LD A,(HL)
        RLA
        LD (HL),A
        INC HL
        LD A,(HL)
        RLA
        LD (HL),A
        INC HL
        LD A,(HL)
        RLA
        LD (HL),A
        INC HL
        LD A,(HL)
        RLA
        LD (HL),A
        DEC B
        JP NZ,FLOW_0D99
        POP BC
        POP HL
        RET

SUBROUTINE_0DB8:
        CALL SUBROUTINE_0DD4

FLOW_0DBB:
        LD A,(HL)
        CALL SUBROUTINE_044C
        LD A,(HL)
        AND A
        INC HL
        JP P,FLOW_0DBB
        RET

SUBROUTINE_0DC6:
        CALL SUBROUTINE_0DD4

SUBROUTINE_0DC9:
        LD A,(HL)
        CALL ADVANCE_DISPLAY_CURSOR
        LD A,(HL)
        AND A
        INC HL
        JP P,SUBROUTINE_0DC9
        RET

SUBROUTINE_0DD4:
        LD HL,$0E1A
        LD A,D
        CALL SUBROUTINE_0C9C
        PUSH HL
        LD HL,$0E4C
        CALL SUBROUTINE_0DE8
        LD A,E
        CALL SUBROUTINE_0C9C
        POP DE
        RET

SUBROUTINE_0DE8:
        IN A,($02)
        RLCA
        RLCA
        RLCA
        AND $03
        JP SUBROUTINE_0C9C

SUBROUTINE_0DF2:
        LD B,$12

FLOW_0DF4:
        LD A,$09

FLOW_0DF6:
        LD C,B

FLOW_0DF7:
        OUT ($01),A
        PUSH AF
        PUSH BC
        CALL SUBROUTINE_0520
        POP BC
        POP AF
        DEC C
        JP NZ,FLOW_0DF7
        ADD A,$10
        JP NC,FLOW_0DF6
        DEC B
        JP NZ,FLOW_0DF4
        LD A,$0A
        OUT ($01),A
        RET
        DB $01,$01,$01,$01,$02,$01,$02,$01,$00,$28,$40,$2A ; ROM $0E12 timing, configuration and address lookup bytes
        DB $00,$2E,$40,$34,$61,$3E,$6C,$0E,$7A,$0E,$8A,$0E ; ROM $0E1E timing, configuration and address lookup bytes
        DB $D5,$0E,$5E,$0E,$62,$0E,$62,$0E,$67,$0E,$F4,$0E ; ROM $0E2A timing, configuration and address lookup bytes
        DB $1B,$00,$FA,$0E,$23,$00,$28,$06,$00,$10,$03,$10 ; ROM $0E36 timing, configuration and address lookup bytes
        DB $06,$10,$9F,$08,$09,$10,$0C,$10,$0F,$10,$24,$0E ; ROM $0E42 timing, configuration and address lookup bytes
        DB $20,$10,$40,$10,$60,$10 ; ROM $0E4E timing, configuration and address lookup bytes
        DB $50,$4C,$41,$59,$45,$D2 ; ROM $0E54 high-bit-terminated screen text and text index bytes
        DB $57,$49,$4E,$D3,$08,$54,$49,$C5,$08,$47,$41,$4D ; ROM $0E5A high-bit-terminated screen text and text index bytes
        DB $C5,$08,$4F,$56,$45,$D2,$07,$54,$4F,$40,$53,$54 ; ROM $0E66 high-bit-terminated screen text and text index bytes
        DB $41,$52,$54,$40,$47,$41,$4D,$C5,$08,$59,$4F,$55 ; ROM $0E72 high-bit-terminated screen text and text index bytes
        DB $40,$48,$41,$56,$45,$40,$43,$52,$45,$44,$49,$D4 ; ROM $0E7E high-bit-terminated screen text and text index bytes
        DB $03,$50,$52,$45,$53,$53,$40,$31,$40,$4F,$52,$40 ; ROM $0E8A high-bit-terminated screen text and text index bytes
        DB $32,$40,$50,$4C,$41,$59,$45,$52,$40,$42,$55,$54 ; ROM $0E96 high-bit-terminated screen text and text index bytes
        DB $54,$4F,$4E,$23,$25,$49,$4E,$53,$45,$52,$54,$40 ; ROM $0EA2 high-bit-terminated screen text and text index bytes
        DB $41,$44,$44,$49,$54,$49,$4F,$4E,$41,$4C,$40,$43 ; ROM $0EAE high-bit-terminated screen text and text index bytes
        DB $4F,$49,$4E,$25,$25,$46,$4F,$52,$40,$33,$40,$4F ; ROM $0EBA high-bit-terminated screen text and text index bytes
        DB $52,$40,$34,$40,$50,$4C,$41,$59,$45,$52,$40,$47 ; ROM $0EC6 high-bit-terminated screen text and text index bytes
        DB $41,$4D,$C5,$40,$50,$52,$45,$53,$53,$40,$31,$40 ; ROM $0ED2 high-bit-terminated screen text and text index bytes
        DB $32,$40,$33,$40,$4F,$52,$40,$34,$40,$50,$4C,$41 ; ROM $0EDE high-bit-terminated screen text and text index bytes
        DB $59,$45,$52,$40,$42,$55,$54,$54,$4F,$CE,$06,$43 ; ROM $0EEA high-bit-terminated screen text and text index bytes
        DB $48,$45,$43,$CB,$04,$49,$4E,$53,$45,$52,$D4,$09 ; ROM $0EF6 high-bit-terminated screen text and text index bytes
        DB $0F,$0C,$0F,$0F,$0F,$14,$0F,$4F,$4E,$C5,$54,$57 ; ROM $0F02 high-bit-terminated screen text and text index bytes
        DB $CF,$54,$48,$52,$45,$C5,$46,$4F,$55,$D2,$20,$0F ; ROM $0F0E high-bit-terminated screen text and text index bytes
        DB $2E,$0F,$3D,$0F,$47,$0F,$42,$49,$54,$45,$53,$40 ; ROM $0F1A high-bit-terminated screen text and text index bytes
        DB $54,$48,$45,$40,$44,$55,$53,$D4,$4D,$45,$45,$54 ; ROM $0F26 high-bit-terminated screen text and text index bytes
        DB $53,$40,$48,$49,$53,$40,$4D,$41,$4B,$45,$D2,$43 ; ROM $0F32 high-bit-terminated screen text and text index bytes
        DB $48,$45,$43,$4B,$53,$40,$4F,$55,$D4,$50,$52,$4F ; ROM $0F3E high-bit-terminated screen text and text index bytes
        DB $4E,$4F,$55,$4E,$43,$45,$44,$40,$44,$45,$41,$C4 ; ROM $0F4A high-bit-terminated screen text and text index bytes
        DB $46,$03,$50,$03,$5A,$03,$64,$03,$FC,$01,$06,$02 ; ROM $0F56 graphics, pointer and game-state lookup tables
        DB $10,$02,$1A,$02,$B4,$04,$BC,$04,$C4,$04,$CC,$04 ; ROM $0F62 graphics, pointer and game-state lookup tables
        DB $76,$0F,$79,$0F,$7C,$0F,$7F,$0F,$3A,$3A,$DB,$3B ; ROM $0F6E graphics, pointer and game-state lookup tables
        DB $3B,$DC,$3C,$3C,$DD,$3D,$3D,$DE,$8A,$0F,$90,$0F ; ROM $0F7A graphics, pointer and game-state lookup tables
        DB $96,$0F,$9C,$0F,$5F,$60,$61,$3E,$62,$E3,$5F,$60 ; ROM $0F86 graphics, pointer and game-state lookup tables
        DB $61,$3E,$64,$E5,$5F,$60,$61,$66,$67,$E8,$5F,$60 ; ROM $0F92 graphics, pointer and game-state lookup tables
        DB $61,$3E,$69,$EA,$C0,$21,$C8,$21,$D0,$21,$D8,$21 ; ROM $0F9E graphics, pointer and game-state lookup tables
        DB $1E,$17,$01,$17,$15,$17,$0B,$17,$00,$FF,$00,$01 ; ROM $0FAA graphics, pointer and game-state lookup tables
        DB $FF,$00,$01,$00,$C8,$0F,$C8,$0F,$CC,$0F,$D2,$0F ; ROM $0FB6 graphics, pointer and game-state lookup tables
        DB $1B,$0B,$04,$0B,$0E,$04,$0F,$13,$00,$24,$18,$24 ; ROM $0FC2 graphics, pointer and game-state lookup tables
        DB $00,$24,$07,$24,$18,$24,$00,$24,$07,$24,$11,$24 ; ROM $0FCE graphics, pointer and game-state lookup tables
        DB $18,$24,$14,$09,$14,$19,$14,$29,$14,$39,$00,$F0 ; ROM $0FDA graphics, pointer and game-state lookup tables
        DB $00,$00,$14,$04,$05,$A9,$05,$19,$05,$79,$00,$32 ; ROM $0FE6 graphics, pointer and game-state lookup tables
        DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; ROM $0FF2 ROM tail zero padding
        DB $00,$00 ; ROM $0FFE ROM tail zero padding
