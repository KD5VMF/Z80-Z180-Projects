; ===============================================================
; PRIMES_SC131.a80 — 8080 (ASM80 -> Intel HEX -> CP/M LOAD)
; SC131 Z180: prints primes forever, correctly.
; Fix: Preseed divisor table with all primes 3..251 (53 entries).
; ===============================================================
.cpu 8080
.org 100h

        JMP     START                  ; CP/M enters here

; ------------------ CONSTANTS ------------------
BDOS    EQU     5
PRINTS  EQU     9
PCOUNT  EQU     53                     ; number of divisors provided below

; ------------------ DATA ------------------
OUTBUF:     DS      8                  ; [digits...][CR][LF]['$']
OUTEND      EQU     OUTBUF+7

; Prime divisors 3..251 (covers √n for all n ≤ 65535)
PRIMES_B:
        DB  3,5,7,11,13,17,19,23,29,31
        DB  37,41,43,47,53,59,61,67,71,73
        DB  79,83,89,97,101,103,107,109,113,127
        DB  131,137,139,149,151,157,163,167,173,179
        DB  181,191,193,197,199,211,223,227,229,233
        DB  239,241,251

CANDLO:     DB      7
CANDHI:     DB      0
PREVLO:     DB      0
PREVHI:     DB      0
INCTGL:     DB      0                  ; 0=>+2, 1=>+4
IDX:        DB      0

N16:        DS      2
PTR:        DS      2

; ------------------ CODE ------------------
START:
        ; print 2, 3, 5 to kick things off
        MVI     D,0
        MVI     E,2
        CALL    PRDEC_CRLF
        MVI     D,0
        MVI     E,3
        CALL    PRDEC_CRLF
        MVI     D,0
        MVI     E,5
        CALL    PRDEC_CRLF

MAIN_LOOP:
        ; remember previous candidate (for wrap detect)
        LDA     CANDLO
        STA     PREVLO
        LDA     CANDHI
        STA     PREVHI

        MVI     A,0
        STA     IDX

TD_NEXT:
        ; if IDX == PCOUNT -> prime (we’ve tested all primes ≤ 251)
        MVI     B,PCOUNT
        LDA     IDX
        CMP     B
        JZ      TD_IS_PRIME

        ; Bdiv = PRIMES_B[IDX]
        LXI     H,PRIMES_B
        MOV     C,A                   ; C = IDX
        MOV     E,C
        MVI     D,0
        DAD     D                     ; HL = PRIMES_B + IDX
        MOV     A,M
        MOV     B,A                   ; B = current prime divisor (3..251)

        ; DE := candidate
        LDA     CANDLO
        MOV     E,A
        LDA     CANDHI
        MOV     D,A

        ; divide candidate by B (DE/B -> quotient in DE, remainder in A)
        CALL    DIV16_8

        ORA     A
        JZ      TD_COMPOSITE          ; divisible -> composite

        ; if (quotient < B) then p^2 > n -> n is prime
        MOV     A,D
        ORA     A
        JNZ     TD_CONT               ; quotient ≥ 256 => not less than B
        MOV     A,E
        CMP     B
        JC      TD_IS_PRIME

TD_CONT:
        LDA     IDX
        INR     A
        STA     IDX
        JMP     TD_NEXT

TD_COMPOSITE:
        JMP     NEXT_CAND

TD_IS_PRIME:
        ; print candidate
        LDA     CANDLO
        MOV     E,A
        LDA     CANDHI
        MOV     D,A
        CALL    PRDEC_CRLF

; ---- Next candidate using 2/4 wheel (skip multiples of 2,3) ----
NEXT_CAND:
        LDA     INCTGL
        ORA     A
        JZ      ADD2
        ; add 4, toggle->0
        MVI     A,0
        STA     INCTGL
        LDA     CANDLO
        ADI     4
        STA     CANDLO
        JNC     WRAPCHK
        LDA     CANDHI
        INR     A
        STA     CANDHI
        JMP     WRAPCHK

ADD2:
        ; add 2, toggle->1
        MVI     A,1
        STA     INCTGL
        LDA     CANDLO
        ADI     2
        STA     CANDLO
        JNC     WRAPCHK
        LDA     CANDHI
        INR     A
        STA     CANDHI

; ---- Detect 16-bit wrap; restart at 7 ----
WRAPCHK:
        LDA     PREVHI
        MOV     B,A
        LDA     CANDHI
        CMP     B
        JC      WRAPPED
        JNZ     LOOP_BACK
        LDA     PREVLO
        MOV     B,A
        LDA     CANDLO
        CMP     B
        JC      WRAPPED
LOOP_BACK:
        JMP     MAIN_LOOP

WRAPPED:
        MVI     A,7
        STA     CANDLO
        XRA     A
        STA     CANDHI
        STA     INCTGL
        JMP     MAIN_LOOP

; ------------------ SUBROUTINES ------------------

; Print DE (0..65535) as decimal + CRLF via BDOS 9
PRDEC_CRLF:
        PUSH    H
        PUSH    B

        LXI     H,OUTEND
        MVI     A,'$'                 ; terminator for BDOS 9
        MOV     M,A
        DCX     H
        MVI     A,10                  ; LF
        MOV     M,A
        DCX     H
        MVI     A,13                  ; CR
        MOV     M,A
        DCX     H
        SHLD    PTR                   ; save write pointer

        ; store N := DE
        XCHG
        SHLD    N16
        XCHG

PRDEC_LOOP:
        LHLD    N16
        XCHG                            ; DE = N
        MVI     B,10
        CALL    DIV16_8                 ; DE=quot, A=rem (0..9)

        LHLD    PTR
        ADI     '0'
        MOV     M,A
        DCX     H
        SHLD    PTR

        XCHG                            ; HL=quot
        SHLD    N16
        MOV     A,H
        ORA     L
        JNZ     PRDEC_LOOP

        LHLD    PTR
        INX     H                        ; first digit
        XCHG                               ; DE -> BDOS string
        MVI     C,PRINTS
        CALL    BDOS

        POP     B
        POP     H
        RET

; Unsigned 16/8 divide: DE / B -> DE=quot, A=rem
DIV16_8:
        XCHG                            ; HL = dividend
        LXI     D,0                     ; quotient = 0
        XRA     A                       ; remainder = 0
        MVI     C,16
D168_LP:
        DAD     H                       ; HL <<= 1, bit15 -> CY
        RAL                               ; A = (A<<1) | CY
        XCHG                             ; HL = quotient
        DAD     H                       ; HL <<= 1
        XCHG                             ; DE = shifted quotient
        CMP     B
        JC      D168_NOSUB
        SUB     B
        INX     D
D168_NOSUB:
        DCR     C
        JNZ     D168_LP
        RET
