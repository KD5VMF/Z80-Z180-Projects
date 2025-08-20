; PRIMES_SC131.a80 — 8080 (ASM80 -> Intel HEX -> CP/M LOAD)
; SC131 Z180: print primes forever (fast, minimal BDOS).
.cpu 8080
.org 100h

        JMP     START          ; ensure execution enters code

; ---- DATA ----
OUTBUF:     DS      8          ; digits + CR LF '$'
OUTEND      EQU     OUTBUF+7

PRIMES_B:   DB      3,5
            DS      62         ; up to 64 small primes total
PCOUNT:     DB      2

CANDLO:     DB      7
CANDHI:     DB      0
PREVLO:     DB      0
PREVHI:     DB      0
INCTGL:     DB      0          ; 0=>+2, 1=>+4
IDX:        DB      0

N16:        DS      2          ; temp 16-bit number for PRDEC
PTR:        DS      2          ; buffer pointer for PRDEC

BDOS    EQU     5
CONOUT  EQU     2
PRINTS  EQU     9

; ---- CODE ----
START:
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
        LDA     CANDLO         ; remember previous candidate
        STA     PREVLO
        LDA     CANDHI
        STA     PREVHI

        MVI     A,0            ; start trial division at index 0
        STA     IDX

TD_NEXT:
        ; if IDX == PCOUNT -> prime
        LDA     PCOUNT
        MOV     B,A
        LDA     IDX
        CMP     B
        JZ      TD_IS_PRIME

        ; B = PRIMES_B[IDX]
        LXI     H,PRIMES_B
        MOV     C,A            ; C = IDX
        MOV     E,C
        MVI     D,0
        DAD     D              ; HL = PRIMES_B + IDX
        MOV     A,M
        MOV     B,A            ; B = current small prime (1..255)

        ; quotient/remainder = CAND / B
        LDA     CANDLO
        MOV     E,A
        LDA     CANDHI
        MOV     D,A
        CALL    DIV16_8        ; DE=quotient, A=remainder

        ORA     A
        JZ      TD_COMPOSITE   ; divisible ⇒ composite

        ; if quotient < B ⇒ p^2 > n ⇒ prime
        MOV     A,D
        ORA     A
        JNZ     TD_CONT
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

        ; store as small prime if ≤255 and room remains
        MOV     A,D
        ORA     A
        JNZ     SKIP_STORE
        LDA     PCOUNT
        CPI     64
        JZ      SKIP_STORE
        LXI     H,PRIMES_B
        MOV     C,A            ; C = PCOUNT
        MOV     E,C
        MVI     D,0
        DAD     D
        LDA     CANDLO
        MOV     M,A
        LDA     PCOUNT
        INR     A
        STA     PCOUNT

SKIP_STORE:
; ---- Next candidate: 2/4 wheel (skip multiples of 2 & 3) ----
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
        JC      WRAPPED         ; CANDHI < PREVHI ⇒ wrapped
        JNZ     LOOP_BACK
        LDA     PREVLO
        MOV     B,A
        LDA     CANDLO
        CMP     B
        JC      WRAPPED         ; CANDLO < PREVLO ⇒ wrapped
LOOP_BACK:
        JMP     MAIN_LOOP

WRAPPED:
        MVI     A,7
        STA     CANDLO
        MVI     A,0
        STA     CANDHI
        MVI     A,0
        STA     INCTGL
        JMP     MAIN_LOOP

; ---- SUBROUTINES ----
; PRDEC_CRLF: print DE (0..65535) as decimal, then CRLF, via BDOS 9
PRDEC_CRLF:
        PUSH    H
        PUSH    B

        LXI     H,OUTEND
        MVI     A,'$'
        MOV     M,A
        DCX     H
        MVI     A,10
        MOV     M,A
        DCX     H
        MVI     A,13
        MOV     M,A
        DCX     H
        SHLD    PTR             ; save write pointer

        ; *** FIX: store the number (DE) into N16 ***
        XCHG                    ; HL := DE
        SHLD    N16             ; N16 := DE
        XCHG                    ; restore HL (buffer pointer is in PTR anyway)

PRDEC_LOOP:
        LHLD    N16
        XCHG                    ; DE = N
        MVI     B,10
        CALL    DIV16_8         ; DE=quotient, A=remainder(0..9)

        LHLD    PTR
        ADI     '0'
        MOV     M,A
        DCX     H
        SHLD    PTR

        XCHG                    ; HL=quotient
        SHLD    N16
        MOV     A,H
        ORA     L
        JNZ     PRDEC_LOOP

        LHLD    PTR
        INX     H              ; first digit
        XCHG                   ; DE=ptr to string
        MVI     C,PRINTS
        CALL    BDOS

        POP     B
        POP     H
        RET

; DIV16_8: Unsigned 16/8 divide (shift–subtract)
; In: DE=dividend, B=divisor(1..255). Out: DE=quotient, A=remainder.
DIV16_8:
        XCHG                    ; HL = dividend
        LXI     D,0            ; quotient = 0
        XRA     A              ; remainder = 0
        MVI     C,16
D168_LP:
        DAD     H              ; HL <<= 1 (bit15->CY)
        RAL                     ; A = (A<<1)|CY
        XCHG                    ; HL = quotient
        DAD     H              ; HL <<= 1
        XCHG                    ; DE = shifted quotient
        CMP     B
        JC      D168_SKIP
        SUB     B
        INX     D
D168_SKIP:
        DCR     C
        JNZ     D168_LP
        RET
