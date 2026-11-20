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

; Inline MAT text following the $0018 service vector.
RST18_INLINE_MAT_TEXT:
        DB $08,$4D,$41,$54,$C5

; Jump vector followed by packed high-bit-terminated COIN label bytes.
RST20_PLAYER_INDEX_VECTOR:
        JP RST20_WRAP_PLAYER_INDEX

; Inline COIN text following the $0020 service vector.
RST20_INLINE_COIN_TEXT:
        DB $08,$43,$4F,$49,$CE

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

; Irq scan player one low.
IRQ_SCAN_PLAYER_ONE_LOW:
        IN A,($00)
        RRCA
        RRCA
        RRCA
        RRCA
        AND $0F
        JP Z,IRQ_SCAN_PLAYER_ONE_HIGH
        LD ($21CA),A

; Irq scan player one high.
IRQ_SCAN_PLAYER_ONE_HIGH:
        IN A,($01)
        AND $0F
        JP Z,IRQ_SCAN_PLAYER_TWO_LOW
        LD ($21D2),A

; Irq scan player two low.
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

; Diag ram record odd error.
DIAG_RAM_RECORD_ODD_ERROR:
        OR E
        LD E,A

; Diag ram forward next.
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

; Diag ram record reverse odd.
DIAG_RAM_RECORD_REVERSE_ODD:
        OR E
        LD E,A

; Diag ram write complement.
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

; Diag ram record complement odd.
DIAG_RAM_RECORD_COMPLEMENT_ODD:
        OR E
        LD E,A

; Diag ram reverse next.
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

; Diag ram record final odd.
DIAG_RAM_RECORD_FINAL_ODD:
        OR E
        LD E,A

; Diag ram clear next.
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

; Diag ram error line.
DIAG_RAM_ERROR_LINE:
        LD HL,$0000
        ADD HL,SP
        LD C,$10

; Diag ram error pixel.
DIAG_RAM_ERROR_PIXEL:
        XOR A
        ADD HL,HL
        JP C,DIAG_RAM_ERROR_WRITE
        CPL

; Diag ram error write.
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

; Diag rom next device.
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

; Reserved bytes preceding display font.
ROM_TEST_VECTOR_PADDING:
        DB $00,$00,$00,$00,$00,$00,$00,$00,$00

; Four ROM-test character codes.
ROM_TEST_CHARACTER_CODES:
        DB $48,$47,$46,$45

; Digit 0 8x10 bitmap.
FONT_DIGIT_0:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Digit 1 8x10 bitmap.
FONT_DIGIT_1:
        DB $18  ; ...##...
        DB $1C  ; ...###..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $3C  ; ..####..

; Digit 2 8x10 bitmap.
FONT_DIGIT_2:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $60  ; .##.....
        DB $7C  ; .#####..
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; Digit 3 8x10 bitmap.
FONT_DIGIT_3:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $60  ; .##.....
        DB $38  ; ..###...
        DB $78  ; .####...
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Digit 4 8x10 bitmap.
FONT_DIGIT_4:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....

; Digit 5 8x10 bitmap.
FONT_DIGIT_5:
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Digit 6 8x10 bitmap.
FONT_DIGIT_6:
        DB $3C  ; ..####..
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Digit 7 8x10 bitmap.
FONT_DIGIT_7:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $70  ; .###....
        DB $30  ; ..##....
        DB $38  ; ..###...
        DB $18  ; ...##...
        DB $1C  ; ...###..
        DB $0C  ; ....##..
        DB $0C  ; ....##..

; Digit 8 8x10 bitmap.
FONT_DIGIT_8:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Digit 9 8x10 bitmap.
FONT_DIGIT_9:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7C  ; .#####..
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $7C  ; .#####..
        DB $3C  ; ..####..

; Blank 8x10 bitmap.
FONT_BLANK:
        DB $00  ; ........
        DB $FF  ; ########
        DB $81  ; #......#
        DB $81  ; #......#
        DB $81  ; #......#
        DB $81  ; #......#
        DB $81  ; #......#
        DB $81  ; #......#
        DB $FF  ; ########
        DB $00  ; ........

; Letter A 8x10 bitmap.
FONT_LETTER_A:
        DB $00  ; ........
        DB $FF  ; ########
        DB $81  ; #......#
        DB $BD  ; #.####.#
        DB $A5  ; #.#..#.#
        DB $A5  ; #.#..#.#
        DB $BD  ; #.####.#
        DB $81  ; #......#
        DB $FF  ; ########
        DB $00  ; ........

; Letter B 8x10 bitmap.
FONT_LETTER_B:
        DB $00  ; ........
        DB $FF  ; ########
        DB $D5  ; ##.#.#.#
        DB $AB  ; #.#.#.##
        DB $D5  ; ##.#.#.#
        DB $AB  ; #.#.#.##
        DB $D5  ; ##.#.#.#
        DB $AB  ; #.#.#.##
        DB $FF  ; ########
        DB $00  ; ........

; Letter C 8x10 bitmap.
FONT_LETTER_C:
        DB $00  ; ........
        DB $FF  ; ########
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $99  ; #..##..#
        DB $99  ; #..##..#
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $FF  ; ########
        DB $00  ; ........

; Letter D 8x10 bitmap.
FONT_LETTER_D:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########

; Letter E 8x10 bitmap.
FONT_LETTER_E:
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $00  ; ........
        DB $00  ; ........
        DB $18  ; ...##...
        DB $18  ; ...##...

; Letter F 8x10 bitmap.
FONT_LETTER_F:
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........

; Letter G 8x10 bitmap.
FONT_LETTER_G:
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Letter H 8x10 bitmap.
FONT_LETTER_H:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.

; Letter I 8x10 bitmap.
FONT_LETTER_I:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Letter J 8x10 bitmap.
FONT_LETTER_J:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.

; Letter K 8x10 bitmap.
FONT_LETTER_K:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; Letter L 8x10 bitmap.
FONT_LETTER_L:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.

; Letter M 8x10 bitmap.
FONT_LETTER_M:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $76  ; .###.##.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Letter N 8x10 bitmap.
FONT_LETTER_N:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Letter O 8x10 bitmap.
FONT_LETTER_O:
        DB $3C  ; ..####..
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $3C  ; ..####..

; Letter P 8x10 bitmap.
FONT_LETTER_P:
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Letter Q 8x10 bitmap.
FONT_LETTER_Q:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $76  ; .###.##.
        DB $3E  ; ..#####.
        DB $1E  ; ...####.
        DB $1E  ; ...####.
        DB $3E  ; ..#####.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Letter R 8x10 bitmap.
FONT_LETTER_R:
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; Letter S 8x10 bitmap.
FONT_LETTER_S:
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $FF  ; ########
        DB $FF  ; ########
        DB $DB  ; ##.##.##
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $C3  ; ##....##

; Letter T 8x10 bitmap.
FONT_LETTER_T:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $6E  ; .##.###.
        DB $6E  ; .##.###.
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $76  ; .###.##.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Letter U 8x10 bitmap.
FONT_LETTER_U:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Letter V 8x10 bitmap.
FONT_LETTER_V:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.
        DB $06  ; .....##.

; Letter W 8x10 bitmap.
FONT_LETTER_W:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $5C  ; .#.###..

; Letter X 8x10 bitmap.
FONT_LETTER_X:
        DB $3E  ; ..#####.
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3E  ; ..#####.
        DB $76  ; .###.##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Letter Y 8x10 bitmap.
FONT_LETTER_Y:
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $06  ; .....##.
        DB $3E  ; ..#####.
        DB $7C  ; .#####..
        DB $60  ; .##.....
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Letter Z 8x10 bitmap.
FONT_LETTER_Z:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; Additional symbol 8x10 bitmap.
FONT_EXTRA_SYMBOL:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..

; Drawing tile 1 8x10 bitmap.
GRAPHIC_TILE_01:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...

; Drawing tile 2 8x10 bitmap.
GRAPHIC_TILE_02:
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $C3  ; ##....##
        DB $DB  ; ##.##.##
        DB $FF  ; ########
        DB $FF  ; ########
        DB $E7  ; ###..###
        DB $E7  ; ###..###
        DB $C3  ; ##....##
        DB $C3  ; ##....##

; Drawing tile 3 8x10 bitmap.
GRAPHIC_TILE_03:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $66  ; .##..##.
        DB $66  ; .##..##.

; Drawing tile 4 8x10 bitmap.
GRAPHIC_TILE_04:
        DB $66  ; .##..##.
        DB $66  ; .##..##.
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; Drawing tile 5 8x10 bitmap.
GRAPHIC_TILE_05:
        DB $7E  ; .######.
        DB $7E  ; .######.
        DB $60  ; .##.....
        DB $70  ; .###....
        DB $38  ; ..###...
        DB $1C  ; ...###..
        DB $0E  ; ....###.
        DB $06  ; .....##.
        DB $7E  ; .######.
        DB $7E  ; .######.

; Drawing tile 6 8x10 bitmap.
GRAPHIC_TILE_06:
        DB $00  ; ........
        DB $FF  ; ########
        DB $EF  ; ###.####
        DB $E7  ; ###..###
        DB $EF  ; ###.####
        DB $EF  ; ###.####
        DB $EF  ; ###.####
        DB $C7  ; ##...###
        DB $FF  ; ########
        DB $00  ; ........

; Drawing tile 7 8x10 bitmap.
GRAPHIC_TILE_07:
        DB $00  ; ........
        DB $FF  ; ########
        DB $C3  ; ##....##
        DB $DB  ; ##.##.##
        DB $DF  ; ##.#####
        DB $C3  ; ##....##
        DB $FB  ; #####.##
        DB $C3  ; ##....##
        DB $FF  ; ########
        DB $00  ; ........

; Drawing tile 8 8x10 bitmap.
GRAPHIC_TILE_08:
        DB $00  ; ........
        DB $FF  ; ########
        DB $C3  ; ##....##
        DB $DF  ; ##.#####
        DB $E7  ; ###..###
        DB $DF  ; ##.#####
        DB $DF  ; ##.#####
        DB $C3  ; ##....##
        DB $FF  ; ########
        DB $00  ; ........

; Drawing tile 9 8x10 bitmap.
GRAPHIC_TILE_09:
        DB $00  ; ........
        DB $FF  ; ########
        DB $DB  ; ##.##.##
        DB $DB  ; ##.##.##
        DB $C3  ; ##....##
        DB $DF  ; ##.#####
        DB $DF  ; ##.#####
        DB $DF  ; ##.#####
        DB $FF  ; ########
        DB $00  ; ........

; Drawing tile 10 8x10 bitmap.
GRAPHIC_TILE_10:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $E8  ; ###.#...
        DB $EA  ; ###.#.#.
        DB $E8  ; ###.#...
        DB $EE  ; ###.###.
        DB $8E  ; #...###.
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 11 8x10 bitmap.
GRAPHIC_TILE_11:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $A8  ; #.#.#...
        DB $AA  ; #.#.#.#.
        DB $88  ; #...#...
        DB $DA  ; ##.##.#.
        DB $DA  ; ##.##.#.
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 12 8x10 bitmap.
GRAPHIC_TILE_12:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $C8  ; ##..#...
        DB $AE  ; #.#.###.
        DB $CC  ; ##..##..
        DB $AE  ; #.#.###.
        DB $A8  ; #.#.#...
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 13 8x10 bitmap.
GRAPHIC_TILE_13:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $47  ; .#...###
        DB $57  ; .#.#.###
        DB $57  ; .#.#.###
        DB $57  ; .#.#.###
        DB $47  ; .#...###
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 14 8x10 bitmap.
GRAPHIC_TILE_14:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $17  ; ...#.###
        DB $D6  ; ##.#.##.
        DB $95  ; #..#.#.#
        DB $D3  ; ##.#..##
        DB $17  ; ...#.###
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 15 8x10 bitmap.
GRAPHIC_TILE_15:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $47  ; .#...###
        DB $6F  ; .##.####
        DB $6F  ; .##.####
        DB $6F  ; .##.####
        DB $EF  ; ###.####
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 16 8x10 bitmap.
GRAPHIC_TILE_16:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $17  ; ...#.###
        DB $57  ; .#.#.###
        DB $55  ; .#.#.#.#
        DB $55  ; .#.#.#.#
        DB $18  ; ...##...
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 17 8x10 bitmap.
GRAPHIC_TILE_17:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $1F  ; ...#####
        DB $BF  ; #.######
        DB $BF  ; #.######
        DB $BF  ; #.######
        DB $BF  ; #.######
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 18 8x10 bitmap.
GRAPHIC_TILE_18:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $95  ; #..#.#.#
        DB $55  ; .#.#.#.#
        DB $91  ; #..#...#
        DB $55  ; .#.#.#.#
        DB $55  ; .#.#.#.#
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 19 8x10 bitmap.
GRAPHIC_TILE_19:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $11  ; ...#...#
        DB $DD  ; ##.###.#
        DB $99  ; #..##..#
        DB $DD  ; ##.###.#
        DB $11  ; ...#...#
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 20 8x10 bitmap.
GRAPHIC_TILE_20:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $11  ; ...#...#
        DB $5D  ; .#.###.#
        DB $59  ; .#.##..#
        DB $5D  ; .#.###.#
        DB $1D  ; ...###.#
        DB $FF  ; ########
        DB $FF  ; ########

; Drawing tile 21 8x10 bitmap.
GRAPHIC_TILE_21:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $FF  ; ########
        DB $95  ; #..#.#.#
        DB $55  ; .#.#.#.#
        DB $95  ; #..#.#.#
        DB $55  ; .#.#.#.#
        DB $51  ; .#.#...#
        DB $FF  ; ########
        DB $FF  ; ########

; Process high-nibble pixel data and call display cursor utility.
ADVANCE_GLYPH_NIBBLE:
        LD A,(HL)
        AND $F0
        JP NZ,DRAW_NIBBLE_FROM_HIGH_BITS
        LD A,$40
        CALL ADVANCE_DISPLAY_CURSOR
        JP DRAW_NEXT_GLYPH_COLUMN
        LD A,(HL)  ; Load glyph byte for the adjacent nibble routine

; Draw nibble from high bits.
DRAW_NIBBLE_FROM_HIGH_BITS:
        RLCA
        RLCA
        RLCA
        RLCA
        CALL DRAW_GLYPH_NIBBLE

; Draw next glyph column.
DRAW_NEXT_GLYPH_COLUMN:
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
        JP NC,DRAW_XOR_SPRITE
        EX DE,HL
        LD BC,$01E0

; Advance display cursor across a 32-byte row boundary.
ADVANCE_DISPLAY_ROW:
        PUSH AF
        INC HL
        LD A,L
        AND $1F
        JP NZ,DRAW_ROW_RESTORE_AND_RETURN
        ADD HL,BC

; Draw row restore and return.
DRAW_ROW_RESTORE_AND_RETURN:
        POP AF
        DEC A
        JP NZ,ADVANCE_DISPLAY_ROW
        EX DE,HL
        RET

; Draw xor sprite.
DRAW_XOR_SPRITE:
        PUSH HL
        PUSH DE
        CALL COMPUTE_GLYPH_OFFSET
        LD A,($21E8)
        LD C,A

; Draw xor sprite row.
DRAW_XOR_SPRITE_ROW:
        PUSH BC
        LD A,(DE)
        INC DE
        XOR C
        LD (HL),A
        LD BC,$0020
        ADD HL,BC
        POP BC
        DEC B
        JP NZ,DRAW_XOR_SPRITE_ROW
        POP DE
        INC DE
        POP HL
        RET

; Compute glyph offset zero page.
COMPUTE_GLYPH_OFFSET_ZERO_PAGE:
        LD B,$00

; Compute glyph offset.
COMPUTE_GLYPH_OFFSET:
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

; Draw encoded character.
DRAW_ENCODED_CHARACTER:
        AND $7F
        PUSH HL
        CP $30
        JP NC,DRAW_CHARACTER_WITH_FONT_OFFSET
        LD L,A
        LD H,$00
        ADD HL,DE
        EX DE,HL
        POP HL
        RET

; Draw character with font offset.
DRAW_CHARACTER_WITH_FONT_OFFSET:
        PUSH DE
        CALL COMPUTE_GLYPH_OFFSET_ZERO_PAGE

; Draw character pixel rows.
DRAW_CHARACTER_PIXEL_ROWS:
        PUSH BC
        LD A,(DE)
        INC DE
        PUSH DE
        PUSH HL
        LD HL,$21E3
        LD BC,$0004

; Draw character select high mask.
DRAW_CHARACTER_SELECT_HIGH_MASK:
        LD E,A
        LD D,B
        RLCA
        JP NC,DRAW_CHARACTER_SELECT_LOW_MASK
        LD D,$F0

; Draw character select low mask.
DRAW_CHARACTER_SELECT_LOW_MASK:
        RLCA
        LD A,B
        JP NC,DRAW_CHARACTER_WRITE_MASKED_PIXEL
        LD A,$0F

; Draw character write masked pixel.
DRAW_CHARACTER_WRITE_MASKED_PIXEL:
        OR D
        LD (HL),A
        DEC HL
        LD A,E
        RLCA
        RLCA
        DEC C
        JP NZ,DRAW_CHARACTER_SELECT_HIGH_MASK
        EX DE,HL
        INC DE
        POP HL
        LD C,$04

; Copy four pixel bytes.
COPY_FOUR_PIXEL_BYTES:
        PUSH DE
        PUSH HL
        LD B,$04

; Copy next pixel byte.
COPY_NEXT_PIXEL_BYTE:
        LD A,(DE)
        INC DE
        LD (HL),A
        INC HL
        DEC B
        JP NZ,COPY_NEXT_PIXEL_BYTE
        POP HL
        LD DE,$0020
        ADD HL,DE
        POP DE
        DEC C
        JP NZ,COPY_FOUR_PIXEL_BYTES
        POP DE
        POP BC
        DEC B
        JP NZ,DRAW_CHARACTER_PIXEL_ROWS
        POP DE
        INC DE
        INC DE
        INC DE
        INC DE
        POP HL
        RET

; Drawing record prefix and zero-valued header bytes.
GAME_GRAPHIC_RECORD_HEADER:
        DB $A3,$00,$00,$00,$00,$00,$00,$00

; Game drawing shape 1 8x10 bitmap.
GAME_GRAPHIC_SHAPE_01:
        DB $00  ; ........
        DB $18  ; ...##...
        DB $3C  ; ..####..
        DB $7E  ; .######.
        DB $FF  ; ########
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...

; Game drawing shape 2 8x10 bitmap.
GAME_GRAPHIC_SHAPE_02:
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $FF  ; ########
        DB $7E  ; .######.
        DB $3C  ; ..####..
        DB $18  ; ...##...
        DB $08  ; ....#...
        DB $0C  ; ....##..
        DB $0E  ; ....###.

; Game drawing shape 3 8x10 bitmap.
GAME_GRAPHIC_SHAPE_03:
        DB $FF  ; ########
        DB $FF  ; ########
        DB $0E  ; ....###.
        DB $0C  ; ....##..
        DB $08  ; ....#...
        DB $10  ; ...#....
        DB $30  ; ..##....
        DB $70  ; .###....
        DB $FF  ; ########
        DB $FF  ; ########

; Game drawing shape 4 8x10 bitmap.
GAME_GRAPHIC_SHAPE_04:
        DB $70  ; .###....
        DB $30  ; ..##....
        DB $10  ; ...#....
        DB $0A  ; ....#.#.
        DB $00  ; ........
        DB $00  ; ........
        DB $00  ; ........
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $00  ; ........

; Game drawing shape 5 8x10 bitmap.
GAME_GRAPHIC_SHAPE_05:
        DB $00  ; ........
        DB $00  ; ........
        DB $0A  ; ....#.#.
        DB $00  ; ........
        DB $00  ; ........
        DB $24  ; ..#..#..
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $24  ; ..#..#..
        DB $00  ; ........

; Game drawing shape 6 8x10 bitmap.
GAME_GRAPHIC_SHAPE_06:
        DB $00  ; ........
        DB $0A  ; ....#.#.
        DB $00  ; ........
        DB $24  ; ..#..#..
        DB $42  ; .#....#.
        DB $18  ; ...##...
        DB $18  ; ...##...
        DB $42  ; .#....#.
        DB $24  ; ..#..#..
        DB $00  ; ........

; Game drawing shape 7 8x10 bitmap.
GAME_GRAPHIC_SHAPE_07:
        DB $14  ; ...#.#..
        DB $52  ; .#.#..#.
        DB $81  ; #......#
        DB $24  ; ..#..#..
        DB $11  ; ...#...#
        DB $88  ; #...#...
        DB $24  ; ..#..#..
        DB $81  ; #......#
        DB $4A  ; .#..#.#.
        DB $00  ; ........

; Game initialization target after diagnostic port-02 gate.
BOOT_GAME_INIT:
        LD SP,$2400
        CALL CLEAR_SCREEN_USING_STACK
        LD HL,$2000
        LD BC,$047E
        CALL CLEAR_WORK_RAM_ZERO
        LD HL,$FFFF
        LD ($200A),HL
        LD ($200C),HL
        JP SHOW_ADDITIONAL_PLAYER_PROMPTS

; Clear work ram zero.
CLEAR_WORK_RAM_ZERO:
        XOR A

; Clear work ram next byte.
CLEAR_WORK_RAM_NEXT_BYTE:
        LD (HL),A
        INC HL
        DEC C
        JP NZ,CLEAR_WORK_RAM_NEXT_BYTE
        DEC B
        JP NZ,CLEAR_WORK_RAM_NEXT_BYTE
        RET

; Game frame service.
GAME_FRAME_SERVICE:
        OUT ($02),A
        LD HL,$2001
        LD A,(HL)
        AND A
        JP Z,GAME_FRAME_POLL_INPUT
        LD (HL),$00
        INC HL
        INC (HL)
        LD DE,$0FE8
        CALL SAVE_GAME_INPUT_POINTER
        LD A,($2006)
        AND A
        RET NZ
        LD SP,$2400
        CALL CLEAR_SCREEN_USING_STACK
        LD DE,$0000

; Game render and input update.
GAME_RENDER_AND_INPUT_UPDATE:
        CALL DRAW_ZERO_TERMINATED_MESSAGE
        CALL UPDATE_PLAYER_SELECTION_DISPLAY

; Wait for next frame.
WAIT_FOR_NEXT_FRAME:
        CALL GAME_FRAME_SERVICE
        JP WAIT_FOR_NEXT_FRAME

; Game frame poll input.
GAME_FRAME_POLL_INPUT:
        LD A,($2003)
        AND A
        JP NZ,GAME_PROCESS_COIN_AND_START
        LD HL,($2004)
        LD A,(HL)
        AND A
        JP Z,GAME_CLEAR_OUTPUT_LATCH
        LD ($2003),A
        INC HL
        LD A,(HL)
        OUT ($01),A
        INC HL
        LD ($2004),HL
        JP GAME_PROCESS_COIN_AND_START

; Game clear output latch.
GAME_CLEAR_OUTPUT_LATCH:
        XOR A
        OUT ($01),A

; Game process coin and start.
GAME_PROCESS_COIN_AND_START:
        CALL READ_ROTATING_INPUT_BITS
        LD A,($2006)
        AND A
        RET NZ
        IN A,($03)
        AND $0F
        RET Z
        LD E,$00

; Game count input pulses.
GAME_COUNT_INPUT_PULSES:
        INC E
        RRCA
        JP NC,GAME_COUNT_INPUT_PULSES
        IN A,($02)
        AND $01
        LD D,A
        LD A,E
        RLCA
        OR D
        LD HL,$0E10
        CALL ADD_INDEX_TO_POINTER
        LD D,A
        LD HL,$2002
        LD A,(HL)
        SUB D
        RET M
        LD (HL),A
        LD A,E
        CP $01
        JP NZ,GAME_STORE_PLAYER_MODE
        LD ($2009),A
        LD A,$04
        LD E,A
        JP GAME_INITIALIZE_PLAYER_COUNT

; Game store player mode.
GAME_STORE_PLAYER_MODE:
        LD ($2009),A

; Game initialize player count.
GAME_INITIALIZE_PLAYER_COUNT:
        LD ($2007),A
        LD A,E
        LD HL,$0FB8
        CALL LOOKUP_INDEXED_WORD_POINTER
        LD ($200E),HL
        LD A,$01
        LD ($2006),A
        LD SP,$2400
        LD HL,$2027
        LD BC,$0296
        CALL CLEAR_WORK_RAM_ZERO
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

; Game advance player state.
GAME_ADVANCE_PLAYER_STATE:
        CALL INITIALIZE_PLAYER_PLAYFIELD
        LD HL,$2010
        RST $20
        LD HL,$2008
        DEC (HL)
        JP NZ,GAME_ADVANCE_PLAYER_STATE
        XOR A
        LD ($2006),A
        LD HL,$2027
        LD A,($2007)
        LD B,A
        LD DE,$0000
        LD C,D

; Game compare player order.
GAME_COMPARE_PLAYER_ORDER:
        LD A,(HL)
        INC HL
        CP C
        JP Z,GAME_COUNT_PLAYER_MATCH
        JP C,GAME_NEXT_PLAYER_COMPARISON
        LD C,A
        LD E,B
        LD D,$FF

; Game count player match.
GAME_COUNT_PLAYER_MATCH:
        INC D

; Game next player comparison.
GAME_NEXT_PLAYER_COMPARISON:
        DEC B
        JP NZ,GAME_COMPARE_PLAYER_ORDER
        LD A,D
        AND A
        JP Z,SELECT_LANGUAGE_INTRO_ENTRY
        LD DE,$0104
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD DE,$0305
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        JP SHOW_INTRO_AND_PLAYER_PROMPTS

; Select language intro entry.
SELECT_LANGUAGE_INTRO_ENTRY:
        LD HL,$0E3C
        CALL SELECT_LANGUAGE_VECTOR
        JP (HL)

; Selected when input port $02 language bits choose language 0; four-way native jump.
LANGUAGE0_INTRO_RENDER:
        PUSH DE
        LD DE,$2A41
        LD HL,$0E54
        CALL DRAW_NEXT_MESSAGE_CHARACTER
        INC DE
        INC DE
        POP BC
        LD A,($2007)
        SUB C
        ADD A,$31
        CALL DRAW_ENCODED_CHARACTER
        LD DE,$3448
        LD HL,$0E5A
        CALL DRAW_NEXT_MESSAGE_CHARACTER

; Show intro and player prompts.
SHOW_INTRO_AND_PLAYER_PROMPTS:
        LD A,$FF
        RST $18
        CALL CLEAR_SCREEN_AND_RESET_CURSOR
        LD DE,$0106
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD DE,$0307
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD DE,$0FE5
        CALL GET_GAME_INPUT_POINTER
        CALL PLAY_ATTRACT_OUTPUT_PATTERN
        LD A,($2002)
        AND A
        JP Z,SHOW_ADDITIONAL_PLAYER_PROMPTS
        CALL CLEAR_SCREEN_USING_STACK
        LD DE,$0001
        JP GAME_RENDER_AND_INPUT_UPDATE

; Show additional player prompts.
SHOW_ADDITIONAL_PLAYER_PROMPTS:
        CALL CLEAR_SCREEN_AND_RESET_CURSOR
        LD DE,$0108
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD DE,$0309
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD A,$78
        RST $18
        CALL CLEAR_SCREEN_AND_RESET_CURSOR
        LD DE,$010A
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD DE,$030B
        CALL DRAW_HIGH_BIT_TERMINATED_MESSAGE
        LD A,$78
        RST $18
        CALL START_PLAYER_ROUND
        JP SHOW_ADDITIONAL_PLAYER_PROMPTS

; Clear screen and reset cursor.
CLEAR_SCREEN_AND_RESET_CURSOR:
        LD DE,$4000
        LD HL,$00C6
        JP FILL_VIDEO_RAM_USING_STACK

; Update player selection display.
UPDATE_PLAYER_SELECTION_DISPLAY:
        LD DE,$0203
        IN A,($02)
        AND $01
        JP NZ,DRAW_ZERO_TERMINATED_MESSAGE
        LD A,($2002)
        CP $02
        JP NC,DRAW_ZERO_TERMINATED_MESSAGE
        LD E,$02
        JP DRAW_ZERO_TERMINATED_MESSAGE

; Initialize player playfield.
INITIALIZE_PLAYER_PLAYFIELD:
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD (HL),$FF
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD (HL),$AA
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD (HL),$FF
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD A,($2010)
        LD (HL),A
        JP INITIALIZE_ROUND_PLAYER_STATE

; Start player round.
START_PLAYER_ROUND:
        LD A,($2007)
        AND A
        RET Z
        LD B,$03

; Scan player playfield.
SCAN_PLAYER_PLAYFIELD:
        CALL ADVANCE_BOARD_RECORD_POINTER
        EX DE,HL
        LD A,(DE)
        INC A
        JP NZ,ADVANCE_ACTIVE_PLAYER_FIELD
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD A,(HL)
        CP $AA
        JP NZ,ADVANCE_ACTIVE_PLAYER_FIELD
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD A,(HL)
        INC A
        JP Z,SCAN_NEXT_PLAYER_RECORD

; Advance active player field.
ADVANCE_ACTIVE_PLAYER_FIELD:
        EX DE,HL
        LD ($202B),HL
        PUSH BC
        CALL GAME_FRAME_SERVICE
        POP BC
        DEC C
        JP NZ,SCAN_PLAYER_PLAYFIELD
        DEC B
        JP NZ,SCAN_PLAYER_PLAYFIELD
        RET

; Scan next player record.
SCAN_NEXT_PLAYER_RECORD:
        CALL ADVANCE_BOARD_RECORD_POINTER
        LD A,($2007)
        CP (HL)
        JP C,ADVANCE_ACTIVE_PLAYER_FIELD
        LD A,(HL)
        AND A
        JP Z,ADVANCE_ACTIVE_PLAYER_FIELD
        LD ($2010),A

; Initialize round player state.
INITIALIZE_ROUND_PLAYER_STATE:
        CALL RESET_ROUND_RESULT_DISPLAY
        LD A,($2010)
        LD ($2011),A
        LD A,($2007)
        LD ($2012),A
        LD A,($2006)
        AND A
        JP Z,ROUND_POLL_ACTIVE_PLAYER
        LD DE,$0FDC
        CALL GET_GAME_INPUT_POINTER
        LD HL,$2017
        LD (HL),$03

; Draw player number glyph.
DRAW_PLAYER_NUMBER_GLYPH:
        LD A,(HL)
        ADD A,$30
        LD DE,$2F8E
        CALL DRAW_ENCODED_CHARACTER
        LD A,$1E
        RST $18
        LD HL,$2017
        DEC (HL)
        JP NZ,DRAW_PLAYER_NUMBER_GLYPH
        LD DE,$2F8E
        LD A,$40
        CALL DRAW_ENCODED_CHARACTER

; Round poll active player.
ROUND_POLL_ACTIVE_PLAYER:
        CALL BEGIN_PLAYER_TURN_UPDATE
        LD A,($2006)
        AND A
        JP Z,ROUND_SET_DEFAULT_DELAY
        LD A,($2009)
        DEC A
        JP NZ,ROUND_CALCULATE_DELAY
        LD A,($21C0)
        AND A

; Round set default delay.
ROUND_SET_DEFAULT_DELAY:
        LD A,$02
        JP Z,ROUND_SAVE_DELAY

; Round calculate delay.
ROUND_CALCULATE_DELAY:
        LD HL,$2012
        LD A,$0B
        SUB (HL)

; Round save delay.
ROUND_SAVE_DELAY:
        LD ($21BF),A

; Round fetch player status.
ROUND_FETCH_PLAYER_STATUS:
        LD HL,$0FA0
        RST $28
        LD A,(HL)
        AND A
        JP NZ,ROUND_TEST_PLAYER_CONTACT
        LD HL,$2011
        RST $20
        JP ROUND_FETCH_PLAYER_STATUS

; Round test player contact.
ROUND_TEST_PLAYER_CONTACT:
        PUSH HL
        CALL READ_BOARD_CELL_RECORD
        AND A
        JP NZ,ROUND_UPDATE_PLAYER_STATUS
        LD A,$04
        CALL CALCULATE_PLAYER_SCREEN_POSITION

; Round update player status.
ROUND_UPDATE_PLAYER_STATUS:
        PUSH HL
        CALL UPDATE_PLAYER_BOARD_CELL
        POP HL
        LD (HL),A
        POP HL
        CALL INITIALIZE_SIX_BYTE_RECORD
        LD A,($2012)
        CP $02
        JP NC,ROUND_ADVANCE_PLAYER_INDEX
        LD A,$78
        RST $18
        RET

; Round advance player index.
ROUND_ADVANCE_PLAYER_INDEX:
        LD HL,$2011
        RST $20
        JP ROUND_POLL_ACTIVE_PLAYER

; Update player board cell.
UPDATE_PLAYER_BOARD_CELL:
        LD B,A
        LD A,($2006)
        AND A
        JP Z,PLAYER_CELL_READ_BITS
        CALL SELECT_PLAYER_CELL_POSITION
        JP P,PLAYER_CELL_NEXT_MASK
        LD (HL),$00

; Player cell next mask.
PLAYER_CELL_NEXT_MASK:
        LD A,B
        DEC A

; Player cell shift left pair.
PLAYER_CELL_SHIFT_LEFT_PAIR:
        DEC C
        JP M,PLAYER_CELL_WRITE_BITS
        RLCA
        RLCA
        JP PLAYER_CELL_SHIFT_LEFT_PAIR

; Player cell write bits.
PLAYER_CELL_WRITE_BITS:
        OR (HL)
        LD (HL),A
        LD A,B
        RET

; Player cell read bits.
PLAYER_CELL_READ_BITS:
        CALL SELECT_PLAYER_CELL_POSITION
        LD A,(HL)

; Player cell shift right pair.
PLAYER_CELL_SHIFT_RIGHT_PAIR:
        DEC C
        JP M,PLAYER_CELL_DECODE_VALUE
        RRCA
        RRCA
        JP PLAYER_CELL_SHIFT_RIGHT_PAIR

; Player cell decode value.
PLAYER_CELL_DECODE_VALUE:
        AND $03
        INC A
        RET

; Select player cell position.
SELECT_PLAYER_CELL_POSITION:
        LD HL,$21BD
        DEC (HL)
        JP P,RESOLVE_PLAYER_CELL_ADDRESS
        LD (HL),$03

; Resolve player cell address.
RESOLVE_PLAYER_CELL_ADDRESS:
        LD C,(HL)
        PUSH AF
        CALL M,ADVANCE_BOARD_RECORD_POINTER
        POP AF
        LD HL,($202B)
        RET

; Advance board record pointer.
ADVANCE_BOARD_RECORD_POINTER:
        LD HL,($202B)
        INC HL
        PUSH AF
        LD A,H
        CP $21
; Branch spans the checkmat.g and checkmat.f device boundary.
        JP NZ,SAVE_BOARD_RECORD_POINTER
        LD A,L
        CP $BD
        JP NZ,SAVE_BOARD_RECORD_POINTER
        LD HL,$202D

; Save board record pointer.
SAVE_BOARD_RECORD_POINTER:
        LD ($202B),HL
        POP AF
        RET

; Initialize six byte record.
INITIALIZE_SIX_BYTE_RECORD:
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
        JP Z,PROCESS_SIX_BYTE_RECORD_FIELDS
        LD HL,$0F5C
        CALL LOOKUP_PLAYER_DRAW_POINTER

; Process six byte record fields.
PROCESS_SIX_BYTE_RECORD_FIELDS:
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
        CALL LOOKUP_PLAYER_DRAW_POINTER
        LD HL,($2013)
        INC HL
        INC HL
        INC HL
        LD A,(HL)
        LD ($2018),A
        LD HL,$0FB0
        CALL LOOKUP_INDEXED_WORD_POINTER
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
        CALL READ_DISPLAY_NIBBLE
        JP NZ,PREPARE_ROUND_RESULT_DISPLAY
        LD A,($2011)
        CALL COMBINE_DISPLAY_NIBBLE
        LD A,($2018)
        LD HL,$0F64
        CALL LOOKUP_INDEXED_WORD_POINTER
        CALL COPY_PLAYER_DISPLAY_RECORD
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
        JP UPDATE_TIMED_INPUT_STATE

; Round-display constant and zero-filled record slots.
ROUND_DISPLAY_PARAMETER_AND_ZERO_SLOTS:
        DB $2A
        DB $00,$00,$00,$00,$00,$00,$00,$00

; Prepare round result display.
PREPARE_ROUND_RESULT_DISPLAY:
        CALL COMPUTE_VIDEO_RAM_ADDRESS
        LD ($2015),HL
        LD BC,$0A28
        CALL UPDATE_TIMED_INPUT_STATE
        LD HL,$0E44
        CALL SELECT_LANGUAGE_VECTOR
        JP (HL)

; Selected from second language dispatch table; round and scoreboard logic.
LANGUAGE0_ROUND_SETUP:
        LD A,$FF
        LD ($21E8),A
        LD DE,$3E61
        LD HL,$0E54
        CALL DRAW_NEXT_ZERO_TERMINATED_CHARACTER
        INC DE
        LD HL,$0EFF
        RST $28
        CALL DRAW_NEXT_ZERO_TERMINATED_CHARACTER
        INC DE
        CALL READ_ROTATING_INPUT_BITS
        AND $03
        LD HL,$0F18
        CALL LOOKUP_INDEXED_WORD_POINTER
        CALL DRAW_NEXT_ZERO_TERMINATED_CHARACTER
        XOR A
        LD ($21E8),A
        LD HL,($2015)
        LD DE,$21E0
        CALL $0D4A
        LD DE,$04D4

; Round winner text loop.
ROUND_WINNER_TEXT_LOOP:
        LD A,(DE)
        INC DE
        AND A
        JP Z,ROUND_WINNER_TEXT_END
        PUSH AF
        LD HL,($2015)
        CALL COPY_EIGHT_DISPLAY_ROWS
        POP AF
        RST $18
        JP ROUND_WINNER_TEXT_LOOP

; Round winner text end.
ROUND_WINNER_TEXT_END:
        LD HL,($2015)
        LD DE,$21E0
        CALL COPY_EIGHT_DISPLAY_ROWS
        LD HL,($2013)
        LD (HL),$00
        LD A,($2006)
        AND A
        JP Z,ROUND_PLAYER_COUNT_LOOP
        LD A,($2011)
        PUSH AF
        LD A,($2007)
        LD ($2011),A

; Round score update loop.
ROUND_SCORE_UPDATE_LOOP:
        LD HL,$0FA0
        RST $28
        LD A,(HL)
        AND A
        JP Z,ROUND_SCORE_UPDATE_DONE
        LD HL,$2026
        CALL LOAD_CURRENT_PLAYER_INDEX
        LD A,(HL)
        INC A
        DAA
        LD (HL),A
        CALL LOAD_CURRENT_PLAYER_DRAW_ADDRESS

; Round score update done.
ROUND_SCORE_UPDATE_DONE:
        LD HL,$2011
        DEC (HL)
        JP NZ,ROUND_SCORE_UPDATE_LOOP
        POP AF
        LD ($2011),A

; Round player count loop.
ROUND_PLAYER_COUNT_LOOP:
        LD HL,$2012
        DEC (HL)
        LD B,$19

; Round player count inner.
ROUND_PLAYER_COUNT_INNER:
        LD C,$1F

; Round player count step.
ROUND_PLAYER_COUNT_STEP:
        LD A,($2011)
        LD E,A
        CALL READ_DISPLAY_NIBBLE
        CP E
        JP NZ,ROUND_PLAYER_COUNT_MISMATCH
        XOR A
        CALL COMBINE_DISPLAY_NIBBLE
        CALL COMPUTE_VIDEO_RAM_ADDRESS
        PUSH BC
        LD B,$08
        XOR A
        CALL FILL_DISPLAY_COLUMN
        POP BC

; Round player count mismatch.
ROUND_PLAYER_COUNT_MISMATCH:
        DEC C
        JP P,ROUND_PLAYER_COUNT_STEP
        DEC B
        JP P,ROUND_PLAYER_COUNT_INNER
        LD A,$04
        LD ($2017),A

; Round end frame loop.
ROUND_END_FRAME_LOOP:
        LD A,($2012)
        LD ($2019),A
        LD ($201A),A

; Round show winner loop.
ROUND_SHOW_WINNER_LOOP:
        LD HL,$201A
        RST $20
        LD A,(HL)
        LD HL,$0FA0
        CALL LOOKUP_INDEXED_WORD_POINTER
        LD A,(HL)
        AND A
        JP Z,ROUND_SHOW_WINNER_LOOP
        LD HL,($200E)
        LD A,($201A)
        CALL LOOKUP_INDEXED_WORD_POINTER
        CALL INVERT_DISPLAY_RECTANGLE
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
        CALL FILL_VIDEO_RAM_USING_STACK
        RET

; Reset round result display.
RESET_ROUND_RESULT_DISPLAY:
        LD DE,$4000
        LD HL,$FF0E
        CALL FILL_VIDEO_RAM_USING_STACK
        LD DE,$3E40
        LD HL,$00B8
        CALL FILL_VIDEO_RAM_USING_STACK
        LD DE,$2740
        LD HL,$FF1A
        CALL FILL_VIDEO_RAM_USING_STACK
        LD HL,$2740
        LD B,$B8
        CALL FILL_DISPLAY_COLUMN_FF
        LD HL,$275F
        LD B,$B8
        CALL FILL_DISPLAY_COLUMN_FF
        LD HL,$21BD
        LD BC,$02C1
        CALL CLEAR_WORK_RAM_ZERO
        LD C,$1F
        LD E,$0F

; Render left border column.
RENDER_LEFT_BORDER_COLUMN:
        LD B,$00
        LD A,E
        CALL COMBINE_DISPLAY_NIBBLE
        LD B,$18
        LD A,E
        CALL COMBINE_DISPLAY_NIBBLE
        DEC C
        JP P,RENDER_LEFT_BORDER_COLUMN
        LD B,$18

; Render right border column.
RENDER_RIGHT_BORDER_COLUMN:
        LD C,$00
        LD A,E
        CALL COMBINE_DISPLAY_NIBBLE
        LD C,$1F
        LD A,E
        CALL COMBINE_DISPLAY_NIBBLE
        DEC B
        JP P,RENDER_RIGHT_BORDER_COLUMN
        LD A,($2006)
        AND A
        JP Z,ROUND_SET_ACTIVE_PLAYERS
        LD A,$FF
        LD ($21E8),A
        LD HL,$2008
        LD DE,$250F
        CALL ADVANCE_GLYPH_NIBBLE
        XOR A
        LD ($21E8),A

; Round set active players.
ROUND_SET_ACTIVE_PLAYERS:
        INC A
        LD ($2017),A
        LD A,($2010)
        LD ($2011),A
        LD A,($2007)

; Round fetch player table.
ROUND_FETCH_PLAYER_TABLE:
        PUSH AF
        LD HL,($200E)
        RST $28
        PUSH HL
        PUSH HL
        CALL INVERT_DISPLAY_RECTANGLE
        LD HL,$0F6C
        RST $28
        EX (SP),HL
        LD BC,$0161
        ADD HL,BC
        EX DE,HL
        POP HL
        CALL DRAW_NEXT_ZERO_TERMINATED_CHARACTER
        CALL LOAD_CURRENT_PLAYER_DRAW_ADDRESS
        LD HL,$0F80
        RST $28
        POP DE
        INC DE
        CALL DRAW_NEXT_ZERO_TERMINATED_CHARACTER
        LD A,($2017)
        LD HL,$0FC0
        CALL LOOKUP_INDEXED_WORD_POINTER
        EX DE,HL
        LD HL,$0FA0
        RST $28
        LD (HL),$01
        INC HL
        LD (HL),$01
        LD A,($2009)
        CP $01
        JP NZ,ROUND_WRITE_PLAYER_RECORD
        DEC (HL)

; Round write player record.
ROUND_WRITE_PLAYER_RECORD:
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
        CALL COMBINE_DISPLAY_NIBBLE
        LD HL,$2017
        INC (HL)
        LD HL,$2011
        RST $20
        POP AF
        DEC A
        JP NZ,ROUND_FETCH_PLAYER_TABLE
        LD A,($2007)
        LD ($2012),A

; Round reload player counter.
ROUND_RELOAD_PLAYER_COUNTER:
        LD A,($2007)
        LD ($2017),A

; Round fetch player display record.
ROUND_FETCH_PLAYER_DISPLAY_RECORD:
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
        JP Z,ROUND_NEXT_PLAYER_DISPLAY
        LD A,B
        CP D
        JP NZ,ROUND_COPY_PLAYER_DISPLAY
        LD A,C
        XOR E
        JP NZ,ROUND_COPY_PLAYER_DISPLAY
        LD (HL),A
        DEC HL
        LD (HL),A
        LD HL,$2012
        DEC (HL)
        JP NZ,ROUND_NEXT_PLAYER_DISPLAY
        RET

; Round copy player display.
ROUND_COPY_PLAYER_DISPLAY:
        PUSH HL
        CALL COMPUTE_VIDEO_RAM_ADDRESS
        PUSH DE
        PUSH BC
        LD B,$08
        XOR A
        CALL FILL_DISPLAY_COLUMN
        POP BC
        POP DE
        LD A,B
        CP D
        CALL CLAMP_SIGNED_PLAYER_INDEX
        LD B,A
        LD A,C
        CP E
        CALL CLAMP_SIGNED_PLAYER_INDEX
        LD C,A
        POP HL
        LD (HL),B
        DEC HL
        LD (HL),C
        LD HL,$0F54
        CALL LOOKUP_PLAYER_DRAW_POINTER

; Round next player display.
ROUND_NEXT_PLAYER_DISPLAY:
        LD HL,$2011
        RST $20
        LD HL,$2017
        DEC (HL)
        JP NZ,ROUND_FETCH_PLAYER_DISPLAY_RECORD
        LD A,$06
        RST $18
        JP ROUND_RELOAD_PLAYER_COUNTER

; Clamp signed player index.
CLAMP_SIGNED_PLAYER_INDEX:
        RET Z
        JP C,INCREMENT_PLAYER_INDEX
        DEC A
        RET

; Increment player index.
INCREMENT_PLAYER_INDEX:
        INC A
        RET

; Independent return opcode at end of player-index adjustment.
PLAYER_INDEX_EXTRA_RETURN:
        RET

; Begin player turn update.
BEGIN_PLAYER_TURN_UPDATE:
        LD A,($2011)
        LD ($201A),A

; Poll player turn delay.
POLL_PLAYER_TURN_DELAY:
        CALL GAME_FRAME_SERVICE
        LD A,($21BF)
        AND A
        RET Z
        LD A,($2006)
        AND A
        JP Z,POLL_PLAYER_TURN_DELAY
        LD A,($201A)
        LD HL,$0FA0
        CALL LOOKUP_INDEXED_WORD_POINTER
        LD A,(HL)
        AND A
        JP Z,ADVANCE_TURN_PLAYER
        PUSH HL
        LD BC,$0006
        ADD HL,BC
        LD A,(HL)
        INC HL
        OR (HL)
        POP HL
        JP Z,ADVANCE_TURN_PLAYER
        INC HL
        LD A,(HL)
        AND A
        JP Z,ADVANCE_TURN_PLAYER
        DEC HL
        CALL READ_BOARD_CELL_RECORD
        LD HL,$0F64
        CALL LOOKUP_INDEXED_WORD_POINTER
        PUSH HL
        CALL COMPUTE_VIDEO_RAM_ADDRESS
        POP DE
        CALL COPY_EIGHT_DISPLAY_ROWS

; Advance turn player.
ADVANCE_TURN_PLAYER:
        LD HL,$201A
        RST $20
        JP POLL_PLAYER_TURN_DELAY

; Read board cell record.
READ_BOARD_CELL_RECORD:
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
        JP NZ,CHECK_BOARD_NEIGHBOR_MASK
        XOR A
        LD ($201B),A
        LD ($2021),A
        LD HL,$21E9
        INC (HL)
        PUSH DE
        LD E,$05
        CALL DRAW_BOARD_CELL_NEIGHBORS
        POP DE
        LD HL,$21E9
        DEC (HL)
        LD HL,$2021
        LD A,(HL)
        AND A
        JP Z,CHECK_BOARD_CELL_ACTIVITY
        LD HL,$21E9
        PUSH AF
        CALL LOAD_CURRENT_PLAYER_INDEX
        POP AF
        DEC (HL)
        JP P,SEARCH_BOARD_CELL_MATCHES
        CALL READ_ROTATING_INPUT_BITS
        AND $0F
        ADD A,$0A
        LD (HL),A
        JP LOAD_FIRST_BOARD_CELL

; Search board cell matches.
SEARCH_BOARD_CELL_MATCHES:
        LD HL,$2021
        LD D,A
        LD A,E
        LD E,D

; Compare next board cell.
COMPARE_NEXT_BOARD_CELL:
        INC HL
        CP (HL)
        JP Z,RETURN_BOARD_CELL_STATUS
        DEC D
        JP NZ,COMPARE_NEXT_BOARD_CELL

; Load first board cell.
LOAD_FIRST_BOARD_CELL:
        LD HL,$2021
        LD A,(HL)
        JP UPDATE_MATCHED_BOARD_CELL

; Check board cell activity.
CHECK_BOARD_CELL_ACTIVITY:
        LD HL,$201B
        LD A,(HL)
        AND A
        JP Z,RETURN_BOARD_CELL_STATUS

; Update matched board cell.
UPDATE_MATCHED_BOARD_CELL:
        CALL CALCULATE_PLAYER_SCREEN_POSITION
        CALL ADD_INDEX_TO_POINTER
        POP HL
        INC HL
        RET

; Return board cell status.
RETURN_BOARD_CELL_STATUS:
        POP HL
        INC HL
        LD A,(HL)
        RET

; Check board neighbor mask.
CHECK_BOARD_NEIGHBOR_MASK:
        CALL DRAW_BOARD_CELL_DEFAULT_MASK
        POP HL
        LD A,(HL)
        INC HL
        AND D
        LD D,A
        LD A,E
        RET Z
        CP $03
        LD A,D
        JP C,COUNT_SET_BITS_NINE
        LD E,$00

; Count set bits shift right.
COUNT_SET_BITS_SHIFT_RIGHT:
        INC E
        RRCA
        JP NC,COUNT_SET_BITS_SHIFT_RIGHT
        LD A,E
        RET

; Count set bits nine.
COUNT_SET_BITS_NINE:
        LD E,$09

; Count set bits shift left.
COUNT_SET_BITS_SHIFT_LEFT:
        DEC E
        RLCA
        JP NC,COUNT_SET_BITS_SHIFT_LEFT
        LD A,E
        RET

; Draw board cell default mask.
DRAW_BOARD_CELL_DEFAULT_MASK:
        LD D,$00

; Draw board cell neighbors.
DRAW_BOARD_CELL_NEIGHBORS:
        CALL DRAW_BOARD_CELL_VERTICAL

; Draw board cell horizontal.
DRAW_BOARD_CELL_HORIZONTAL:
        INC B
        CALL DRAW_BOARD_CELL_EDGE
        DEC B
        DEC B
        CALL DRAW_BOARD_CELL_EDGE
        INC B
        RET

; Draw board cell vertical.
DRAW_BOARD_CELL_VERTICAL:
        INC C
        CALL DRAW_BOARD_CELL_EDGE
        DEC C
        DEC C
        CALL DRAW_BOARD_CELL_EDGE
        INC C
        RET

; Draw board cell edge.
DRAW_BOARD_CELL_EDGE:
        LD A,($21E9)
        AND A
        JP NZ,DECREMENT_BOARD_CELL_MASK
        PUSH HL
        CALL READ_DISPLAY_NIBBLE
        LD A,D
        JP NZ,SAVE_BOARD_CELL_ROTATED_MASK
        OR $80

; Save board cell rotated mask.
SAVE_BOARD_CELL_ROTATED_MASK:
        RLCA
        LD D,A
        POP HL
        RET

; Decrement board cell mask.
DECREMENT_BOARD_CELL_MASK:
        DEC A
; Branch spans the checkmat.f and checkmat.e device boundary.
        JP NZ,DRAW_BOARD_CELL_CHECK_PIXEL
        DEC E
        CALL READ_DISPLAY_NIBBLE
        RET NZ
        LD HL,$201B
        INC (HL)
        LD A,(HL)
        CALL ADD_INDEX_TO_POINTER
        LD (HL),E
        LD HL,$21E9
        INC (HL)
        LD A,E
        LD D,$00
        CP $03
        JP C,ADVANCE_BOARD_CELL_DRAW
        CALL DRAW_BOARD_CELL_HORIZONTAL
        JP DRAW_BOARD_CELL_TIMER_TICK

; Advance board cell draw.
ADVANCE_BOARD_CELL_DRAW:
        CALL DRAW_BOARD_CELL_VERTICAL

; Draw board cell timer tick.
DRAW_BOARD_CELL_TIMER_TICK:
        LD HL,$21E9
        DEC (HL)
        LD A,D
        AND A
        RET Z
        LD HL,$2021
        INC (HL)
        LD A,(HL)
        CALL ADD_INDEX_TO_POINTER
        LD (HL),E
        RET

; Draw board cell check pixel.
DRAW_BOARD_CELL_CHECK_PIXEL:
        CALL READ_DISPLAY_NIBBLE
        RET NZ
        INC D
        RET

; Combine display nibble.
COMBINE_DISPLAY_NIBBLE:
        PUSH HL
        PUSH DE
        PUSH AF
        CALL COMPUTE_DISPLAY_PIXEL_ADDRESS
        LD A,(HL)
        JP C,COMBINE_DISPLAY_HIGH_NIBBLE
        AND $0F
        LD E,A
        POP AF
        RLCA
        RLCA
        RLCA
        RLCA
        JP STORE_COMBINED_DISPLAY_BYTE

; Combine display high nibble.
COMBINE_DISPLAY_HIGH_NIBBLE:
        AND $F0
        LD E,A
        POP AF

; Store combined display byte.
STORE_COMBINED_DISPLAY_BYTE:
        OR E
        LD (HL),A
        POP DE
        POP HL
        RET

; Read display nibble.
READ_DISPLAY_NIBBLE:
        PUSH HL
        PUSH DE
        CALL COMPUTE_DISPLAY_PIXEL_ADDRESS
        LD A,(HL)
        JP C,READ_DISPLAY_LOW_NIBBLE
        RRCA
        RRCA
        RRCA
        RRCA

; Read display low nibble.
READ_DISPLAY_LOW_NIBBLE:
        AND $0F
        POP DE
        POP HL
        RET

; Compute display pixel address.
COMPUTE_DISPLAY_PIXEL_ADDRESS:
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

; Compute video ram address.
COMPUTE_VIDEO_RAM_ADDRESS:
        PUSH AF
        LD A,C
        ADD A,$40
        LD L,A
        LD A,B
        ADC A,$26
        LD H,A
        POP AF
        RET

; Load current player index.
LOAD_CURRENT_PLAYER_INDEX:
        LD A,($2011)

; Add index to pointer.
ADD_INDEX_TO_POINTER:
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

; Lookup indexed word pointer.
LOOKUP_INDEXED_WORD_POINTER:
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
        JP Z,MARK_PLAYER_RECORD_ACTIVE
        INC (HL)
        RET

; Mark player record active.
MARK_PLAYER_RECORD_ACTIVE:
        LD (HL),$01
        RET

; Calculate player screen position.
CALCULATE_PLAYER_SCREEN_POSITION:
        PUSH HL
        PUSH DE
        PUSH AF
        CALL READ_ROTATING_INPUT_BITS
        LD E,A
        LD D,$00
        LD H,D
        LD L,D
        POP AF

; Advance player screen offset.
ADVANCE_PLAYER_SCREEN_OFFSET:
        ADD HL,DE
        DEC A
        JP NZ,ADVANCE_PLAYER_SCREEN_OFFSET
        LD A,H
        INC A
        POP DE
        POP HL
        RET

; Load current player draw address.
LOAD_CURRENT_PLAYER_DRAW_ADDRESS:
        LD HL,($200E)
        RST $28
        LD BC,$0165
        ADD HL,BC
        PUSH HL
        LD HL,$2026
        CALL LOAD_CURRENT_PLAYER_INDEX
        POP DE
        JP ADVANCE_GLYPH_NIBBLE

; Fill display column ff.
FILL_DISPLAY_COLUMN_FF:
        LD A,$FF

; Fill display column.
FILL_DISPLAY_COLUMN:
        LD DE,$0020

; Fill display next row.
FILL_DISPLAY_NEXT_ROW:
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,FILL_DISPLAY_NEXT_ROW
        RET

; Invert display rectangle.
INVERT_DISPLAY_RECTANGLE:
        LD DE,$0140
        ADD HL,DE
        LD DE,$0019
        LD B,$0C

; Invert display row high bits.
INVERT_DISPLAY_ROW_HIGH_BITS:
        LD A,(HL)
        XOR $C0
        LD (HL),A
        INC HL
        LD C,$06

; Invert display next byte.
INVERT_DISPLAY_NEXT_BYTE:
        LD A,(HL)
        CPL
        LD (HL),A
        INC HL
        DEC C
        JP NZ,INVERT_DISPLAY_NEXT_BYTE
        LD A,(HL)
        XOR $03
        LD (HL),A
        ADD HL,DE
        DEC B
        JP NZ,INVERT_DISPLAY_ROW_HIGH_BITS
        RET

; Clear screen using stack.
CLEAR_SCREEN_USING_STACK:
        LD DE,$4000
        LD HL,$00E0

; Fill video ram using stack.
FILL_VIDEO_RAM_USING_STACK:
        LD B,H
        LD C,H
        LD A,L
        LD HL,$0000
        ADD HL,SP
        EX DE,HL
        DI
        LD SP,HL

; Stack fill next block.
STACK_FILL_NEXT_BLOCK:
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
        JP NZ,STACK_FILL_NEXT_BLOCK
        EX DE,HL
        LD SP,HL
        EI
        RET

; Lookup player draw pointer.
LOOKUP_PLAYER_DRAW_POINTER:
        RST $28

; Copy player display record.
COPY_PLAYER_DISPLAY_RECORD:
        PUSH HL
        CALL COMPUTE_VIDEO_RAM_ADDRESS
        POP DE

; Copy eight display rows.
COPY_EIGHT_DISPLAY_ROWS:
        LD B,$08
        LD C,$20

; Copy display row byte.
COPY_DISPLAY_ROW_BYTE:
        LD A,(DE)
        INC DE
        LD (HL),A
        LD A,B
        LD B,$00
        ADD HL,BC
        DEC A
        LD B,A
        JP NZ,COPY_DISPLAY_ROW_BYTE
        RET

; Copy eight indexed rows to the video cursor.
COPY_EIGHT_ROWS_TO_DISPLAY:
        LD B,$08
        LD C,$20

; Copy eight rows next.
COPY_EIGHT_ROWS_NEXT:
        LD A,(HL)
        LD (DE),A
        INC DE
        LD A,B
        LD B,$00
        ADD HL,BC
        LD B,A
        DEC B
        JP NZ,COPY_EIGHT_ROWS_NEXT
        RET

; Update timed input state.
UPDATE_TIMED_INPUT_STATE:
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

; Return when active-game RAM $2006 is zero.
CHECK_GAME_ACTIVE:
        LD A,($2006)
        AND A
        RET Z

; Get game input pointer.
GET_GAME_INPUT_POINTER:
        LD HL,($2004)
        LD A,(HL)
        AND A

; Save game input pointer.
SAVE_GAME_INPUT_POINTER:
        EX DE,HL
        LD ($2004),HL
        RET

; RST $18: wait while RAM $21BE countdown is nonzero, servicing $0520.
RST18_WAIT_TIMER:
        LD ($21BE),A
        PUSH BC
        PUSH DE
        PUSH HL

; Wait for countdown zero.
WAIT_FOR_COUNTDOWN_ZERO:
        CALL GAME_FRAME_SERVICE
        LD A,($21BE)
        AND A
        JP NZ,WAIT_FOR_COUNTDOWN_ZERO
        POP HL
        POP DE
        POP BC
        RET

; Read rotating input bits.
READ_ROTATING_INPUT_BITS:
        PUSH HL
        PUSH BC
        LD HL,$200A
        LD B,$08
        LD A,(HL)

; Rotate next input bit.
ROTATE_NEXT_INPUT_BIT:
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
        JP NZ,ROTATE_NEXT_INPUT_BIT
        POP BC
        POP HL
        RET

; Draw high bit terminated message.
DRAW_HIGH_BIT_TERMINATED_MESSAGE:
        CALL SELECT_LANGUAGE_MESSAGE_POINTER

; Draw next message character.
DRAW_NEXT_MESSAGE_CHARACTER:
        LD A,(HL)
        CALL DRAW_ENCODED_CHARACTER
        LD A,(HL)
        AND A
        INC HL
        JP P,DRAW_NEXT_MESSAGE_CHARACTER
        RET

; Draw zero terminated message.
DRAW_ZERO_TERMINATED_MESSAGE:
        CALL SELECT_LANGUAGE_MESSAGE_POINTER

; Draw next zero terminated character.
DRAW_NEXT_ZERO_TERMINATED_CHARACTER:
        LD A,(HL)
        CALL ADVANCE_DISPLAY_CURSOR
        LD A,(HL)
        AND A
        INC HL
        JP P,DRAW_NEXT_ZERO_TERMINATED_CHARACTER
        RET

; Select language message pointer.
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

; Select language vector.
SELECT_LANGUAGE_VECTOR:
        IN A,($02)
        RLCA
        RLCA
        RLCA
        AND $03
        JP LOOKUP_INDEXED_WORD_POINTER

; Play attract output pattern.
PLAY_ATTRACT_OUTPUT_PATTERN:
        LD B,$12

; Attract pattern next cycle.
ATTRACT_PATTERN_NEXT_CYCLE:
        LD A,$09

; Attract pattern next output.
ATTRACT_PATTERN_NEXT_OUTPUT:
        LD C,B

; Attract pattern pulse delay.
ATTRACT_PATTERN_PULSE_DELAY:
        OUT ($01),A
        PUSH AF
        PUSH BC
        CALL GAME_FRAME_SERVICE
        POP BC
        POP AF
        DEC C
        JP NZ,ATTRACT_PATTERN_PULSE_DELAY
        ADD A,$10
        JP NC,ATTRACT_PATTERN_NEXT_OUTPUT
        DEC B
        JP NZ,ATTRACT_PATTERN_NEXT_CYCLE
        LD A,$0A
        OUT ($01),A
        RET

; Game timing and option bytes.
GAME_TIMING_CONFIGURATION:
        DB $01,$01,$01,$01,$02,$01,$02,$01

; Indexed display and game address words.
GAME_ADDRESS_LOOKUP_WORDS:
        DB $00,$28,$40,$2A,$00,$2E,$40,$34,$61,$3E,$6C,$0E
        DB $7A,$0E,$8A,$0E,$D5,$0E,$5E,$0E,$62,$0E,$62,$0E
        DB $67,$0E,$F4,$0E,$1B,$00,$FA,$0E,$23,$00

; Four language-selected native intro entry points.
LANGUAGE_INTRO_NATIVE_VECTORS:
        DW $0628
        DW $1000
        DW $1003
        DW $1006

; Four language-selected native round entry points.
LANGUAGE_ROUND_NATIVE_VECTORS:
        DW $089F
        DW $1009
        DW $100C
        DW $100F

; Language-specific message address words.
LANGUAGE_MESSAGE_OFFSETS:
        DB $24,$0E,$20,$10,$40,$10,$60,$10

; English player, score and game-over messages, high-bit termination.
ENGLISH_DISPLAY_MESSAGES:
        DB $50,$4C,$41,$59,$45,$D2,$57,$49,$4E,$D3,$08,$54
        DB $49,$C5,$08,$47,$41,$4D,$C5,$08,$4F,$56,$45,$D2
        DB $07,$54,$4F,$40,$53,$54,$41,$52,$54,$40,$47,$41
        DB $4D,$C5,$08,$59,$4F,$55,$40,$48,$41,$56,$45,$40
        DB $43,$52,$45,$44,$49,$D4,$03,$50,$52,$45,$53,$53
        DB $40,$31,$40,$4F,$52,$40,$32,$40,$50,$4C,$41,$59
        DB $45,$52,$40,$42,$55,$54,$54,$4F,$4E,$23,$25,$49
        DB $4E,$53,$45,$52,$54,$40,$41,$44,$44,$49,$54,$49
        DB $4F,$4E,$41,$4C,$40,$43,$4F,$49,$4E,$25,$25,$46
        DB $4F,$52,$40,$33,$40,$4F,$52,$40,$34,$40,$50,$4C
        DB $41,$59,$45,$52,$40,$47,$41,$4D,$C5,$40,$50,$52
        DB $45,$53,$53,$40,$31,$40,$32,$40,$33,$40,$4F,$52
        DB $40,$34,$40,$50,$4C,$41,$59,$45,$52,$40,$42,$55
        DB $54,$54,$4F,$CE,$06,$43,$48,$45,$43,$CB,$04,$49
        DB $4E,$53,$45,$52,$D4,$09,$0F,$0C,$0F,$0F,$0F,$14
        DB $0F,$4F,$4E,$C5,$54,$57,$CF,$54,$48,$52,$45,$C5
        DB $46,$4F,$55,$D2,$20,$0F,$2E,$0F,$3D,$0F,$47,$0F
        DB $42,$49,$54,$45,$53,$40,$54,$48,$45,$40,$44,$55
        DB $53,$D4,$4D,$45,$45,$54,$53,$40,$48,$49,$53,$40
        DB $4D,$41,$4B,$45,$D2,$43,$48,$45,$43,$4B,$53,$40
        DB $4F,$55,$D4,$50,$52,$4F,$4E,$4F,$55,$4E,$43,$45
        DB $44,$40,$44,$45,$41,$C4

; Pointers to font graphics and drawing records.
FONT_AND_DRAWING_POINTERS:
        DB $46,$03,$50,$03,$5A,$03,$64,$03,$FC,$01,$06,$02
        DB $10,$02,$1A,$02,$B4,$04,$BC,$04,$C4,$04,$CC,$04

; Graphics selector records and small drawing tables.
GRAPHICS_SELECTOR_RECORDS:
        DB $76,$0F,$79,$0F,$7C,$0F,$7F,$0F,$3A,$3A,$DB,$3B
        DB $3B,$DC,$3C,$3C,$DD,$3D,$3D,$DE,$8A,$0F,$90,$0F
        DB $96,$0F,$9C,$0F,$5F,$60,$61,$3E,$62,$E3,$5F,$60
        DB $61,$3E,$64,$E5,$5F,$60,$61,$66,$67,$E8,$5F,$60
        DB $61,$3E

; Player and board record address table.
PLAYER_RECORD_ADDRESS_TABLE:
        DB $69,$EA,$C0,$21,$C8,$21,$D0,$21,$D8,$21,$1E,$17
        DB $01,$17,$15,$17,$0B,$17,$00,$FF,$00,$01,$FF,$00
        DB $01,$00,$C8,$0F,$C8,$0F,$CC,$0F,$D2,$0F,$1B,$0B
        DB $04,$0B,$0E,$04

; Video RAM addresses and player position records.
DISPLAY_POSITION_ADDRESS_TABLE:
        DB $0F,$13,$00,$24,$18,$24,$00,$24,$07,$24,$18,$24
        DB $00,$24,$07,$24,$11,$24,$18,$24,$14,$09,$14,$19
        DB $14,$29,$14,$39,$00,$F0

; Final configuration and data words.
GAME_END_CONFIGURATION:
        DB $00,$00,$14,$04,$05,$A9,$05,$19,$05,$79,$00,$32

; Unused zero-filled bytes to end of final 1 KB device.
ROM_TAIL_ZERO_PADDING:
        DB $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
        DB $00,$00
