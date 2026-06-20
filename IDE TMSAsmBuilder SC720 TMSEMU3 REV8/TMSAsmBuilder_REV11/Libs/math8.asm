; math8.asm
; Tiny reusable Z80/Z180 math/display helpers for TMSEMU3 demos.
;
; Kept simple on purpose: no system calls, no dependencies, sjasmplus syntax.

IFNDEF MATH8_ASM
MATH8_ASM: equ 1

; 8-bit Galois-style pseudo-random step.
; Uses MathRandSeed RAM byte.  Returns new random byte in A.
MathRand8:
        ld      a,(MathRandSeed)
        rrca
        jp      nc,MathRandStore
        xor     0b8h
MathRandStore:
        ld      (MathRandSeed),a
        ret

; A = value, returns absolute value treating A as signed -128..+127.
MathAbs8:
        cp      80h
        ret     c
        ld      c,a
        xor     a
        sub     c
        ret

; Increment decimal digit at (HL), range 0..9.
; Carry set if digit rolled 9->0.
MathIncDecDigit:
        inc     (hl)
        ld      a,(hl)
        cp      10
        jp      c,MathIncNoCarry
        xor     a
        ld      (hl),a
        scf
        ret
MathIncNoCarry:
        or      a
        ret

; A = nibble, returns ASCII hex in A.
MathHexNibble:
        and     0fh
        cp      10
        jp      c,MathHexDigit
        add     a,'A'-10
        ret
MathHexDigit:
        add     a,'0'
        ret

; A = 0..8, returns low-bit LED bar mask.
MathBar8:
        and     0fh
        cp      9
        jp      c,MathBarOk
        ld      a,8
MathBarOk:
        ld      e,a
        ld      d,0
        ld      hl,MathBarTable
        add     hl,de
        ld      a,(hl)
        ret

MathBarTable:
        defb    00h,01h,03h,07h,0fh,1fh,3fh,7fh,0ffh

MathRandSeed:   defb 0a7h

ENDIF
