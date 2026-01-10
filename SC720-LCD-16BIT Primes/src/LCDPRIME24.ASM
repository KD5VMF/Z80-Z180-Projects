;===============================================================================
;  LCDPRIME24.ASM  (8080 / 8085 compatible, runs on Z80 too)
;
;  SC720 Z80 board - Prime display (24-bit capable)
;
;  What this does:
;    - Computes PRIME numbers using FULLY EXACT trial division (no heuristics)
;    - Candidate range: 24-bit unsigned (0 .. 16,777,215)  [0x000000..0xFFFFFF]
;    - Displays ONE prime at a time at LCD row1/col0 (top-left)
;    - Each new prime OVERWRITES the previous one (in-place), and clears trailing
;      characters so digit-count changes don't leave junk.
;    - Adjustable small wait between primes (variable at top).
;
;  Why 24-bit is still practical with trial division:
;    - For 24-bit max N, sqrt(N) < 4096, so the divisor loop is bounded.
;
;  LCD interface matches your working SC719/SC720-style 4-bit latch:
;    PORT_LCD is the LCD control/data latch.
;      bit2 = RS  (0=command, 1=data)
;      bit3 = E   (enable pulse)
;      bit4-7 = D4-D7 (4-bit data bus)
;    R/W tied low (write-only)
;
;  Assemble as .COM style (ORG 0100h) and run.
;===============================================================================

            ORG     0100H
            JMP     START

;---------------------- CONFIG -------------------------------------------------
PORT_LCD    EQU     00H            ; MUST match your working LCD program port
LINE1       EQU     00H            ; DDRAM base for row 1

; Speed control (EASY ADJUST):
;   Smaller = faster, larger = slower.
;   Try: 01h..08h = fast, 10h..40h = slower.
PRIME_DELAY_OUTER EQU 06H          ; <<< CHANGE THIS ONE VALUE

; Inner delay constant (leave this alone unless you change CPU speed a lot)
PRIME_DELAY_INNER EQU 3000H

;===============================================================================
START:
            DI
            LXI     SP,STACKEND

            CALL    DELAY_60MS
            CALL    LCD_INIT_4BIT
            CALL    LCD_CLEAR

            ; Candidate = 2 (24-bit)
            MVI     A,02H
            STA     CAND0
            XRA     A
            STA     CAND1
            STA     CAND2

MAIN_LOOP:
            ; Prime?
            CALL    IS_PRIME24
            ORA     A
            JZ      NEXT_CAND

            ; Display this prime at row1/col0 (overwrite previous)
            CALL    DISPLAY_CAND_TOPLEFT

            ; Small adjustable wait
            CALL    PRIME_DELAY

NEXT_CAND:
            ; candidate progression: 2,3,5,7,9,... (skip evens after 2)
            ; if CAND == 2 -> set to 3
            LDA     CAND2
            ORA     A
            JNZ     ADD2
            LDA     CAND1
            ORA     A
            JNZ     ADD2
            LDA     CAND0
            CPI     02H
            JNZ     ADD2

            MVI     A,03H
            STA     CAND0
            XRA     A
            STA     CAND1
            STA     CAND2
            JMP     MAIN_LOOP

ADD2:
            ; CAND += 2 (24-bit)
            LDA     CAND0
            ADI     02H
            STA     CAND0
            LDA     CAND1
            ACI     00H
            STA     CAND1
            LDA     CAND2
            ACI     00H
            STA     CAND2

            ; Optional wrap protection: if it ever wraps into 0/1/2, jump to 3
            LDA     CAND2
            ORA     A
            JNZ     MAIN_LOOP
            LDA     CAND1
            ORA     A
            JNZ     MAIN_LOOP
            LDA     CAND0
            CPI     03H
            JNC     MAIN_LOOP

            MVI     A,03H
            STA     CAND0
            XRA     A
            STA     CAND1
            STA     CAND2
            JMP     MAIN_LOOP

;===============================================================================
; DISPLAY_CAND_TOPLEFT
;   Converts 24-bit CAND to ASCII, prints at row1/col0, pads spaces to col 15.
;===============================================================================
DISPLAY_CAND_TOPLEFT:
            CALL    U24_TO_DEC_ASCII

            ; cursor row1 col0
            MVI     A,LINE1
            CALL    LCD_SET_DDRAM

            ; print digits
            LXI     H,OUTBUF
            LDA     OUTLEN
            MOV     C,A              ; C=len
            MOV     B,A
            CALL    LCD_PUTN

            ; pad spaces to end of row (16 - len)
            MVI     A,10H
            SUB     C
            MOV     B,A
            MOV     A,B
            ORA     A
            RZ
PADLP:
            MVI     A,' '
            CALL    LCD_BYTE_DATA
            DCR     B
            JNZ     PADLP
            RET

;===============================================================================
; PRIME_DELAY  (crude adjustable throttle)
;===============================================================================
PRIME_DELAY:
            PUSH    B
            PUSH    H
            MVI     B,PRIME_DELAY_OUTER
PD_OUT:
            LXI     H,PRIME_DELAY_INNER
PD_IN:
            DCX     H
            MOV     A,H
            ORA     L
            JNZ     PD_IN
            DCR     B
            JNZ     PD_OUT
            POP     H
            POP     B
            RET

;===============================================================================
; IS_PRIME24  (EXACT)
;   Input:  CAND2:CAND1:CAND0  (24-bit unsigned)
;   Output: A=01h if prime, A=00h if not prime
;
;   Algorithm:
;     - Handle n<2, n==2, even
;     - For odd n: test d = 3,5,7,... while d*d <= n
;       If n mod d == 0 => composite, else continue
;===============================================================================
IS_PRIME24:
            ; n == 2?
            LDA     CAND2
            ORA     A
            JNZ     IP24_NOT2
            LDA     CAND1
            ORA     A
            JNZ     IP24_NOT2
            LDA     CAND0
            CPI     02H
            JZ      IP24_PRIME

IP24_NOT2:
            ; n < 2 ? (only possible if high bytes 0)
            LDA     CAND2
            ORA     A
            JNZ     IP24_EVENCHK
            LDA     CAND1
            ORA     A
            JNZ     IP24_EVENCHK
            LDA     CAND0
            CPI     02H
            JC      IP24_NOT

IP24_EVENCHK:
            ; even?
            LDA     CAND0
            ANI     01H
            JZ      IP24_NOT

            ; divisor d = 3 (16-bit) -> DIVLO/DIVHI
            MVI     A,03H
            STA     DIVLO
            XRA     A
            STA     DIVHI

IP24_LOOP:
            ; SQ = d*d (24-bit)
            CALL    SQUARE_DIV_TO_SQ24

            ; if SQ > N => prime
            ; compare high byte first: SQ2 vs CAND2
            LDA     SQ2
            MOV     B,A
            LDA     CAND2
            CMP     B               ; A - B  (CAND2 - SQ2)
            JC      IP24_PRIME      ; CAND2 < SQ2  => SQ > N
            JNZ     IP24_DO_MOD     ; CAND2 > SQ2  => SQ < N
            ; mid
            LDA     SQ1
            MOV     B,A
            LDA     CAND1
            CMP     B
            JC      IP24_PRIME
            JNZ     IP24_DO_MOD
            ; low
            LDA     SQ0
            MOV     B,A
            LDA     CAND0
            CMP     B
            JC      IP24_PRIME
            ; equal or smaller => continue to mod
IP24_DO_MOD:
            ; remainder = N mod d
            CALL    MOD24_BY_DIV16   ; remainder in REMHI:REMLO
            LDA     REMHI
            ORA     A
            JNZ     IP24_NEXTD
            LDA     REMLO
            ORA     A
            JZ      IP24_NOT         ; divisible

IP24_NEXTD:
            ; d += 2
            LDA     DIVLO
            ADI     02H
            STA     DIVLO
            LDA     DIVHI
            ACI     00H
            STA     DIVHI
            JMP     IP24_LOOP

IP24_PRIME:
            MVI     A,01H
            RET
IP24_NOT:
            XRA     A
            RET

;===============================================================================
; SQUARE_DIV_TO_SQ24
;   Computes SQ = d*d where d is 16-bit in DIVHI:DIVLO.
;   Output: SQ2:SQ1:SQ0 (24-bit)
;===============================================================================
SQUARE_DIV_TO_SQ24:
            ; multiplicand M = d (24-bit)
            LDA     DIVLO
            STA     M0
            STA     WMUL0           ; multiplier low
            LDA     DIVHI
            STA     M1
            STA     WMUL1           ; multiplier high
            XRA     A
            STA     M2

            ; result SQ = 0
            XRA     A
            STA     SQ0
            STA     SQ1
            STA     SQ2

            ; 16-bit shift/add multiply
            MVI     B,10H           ; 16 iterations

SQM_LOOP:
            ; if (multiplier & 1) add M to SQ
            LDA     WMUL0
            ANI     01H
            JZ      SQM_NOADD

            ; SQ += M  (24-bit add)
            LDA     SQ0
            MOV     C,A
            LDA     M0
            ADD     C
            STA     SQ0

            LDA     SQ1
            MOV     C,A
            LDA     M1
            ADC     C
            STA     SQ1

            LDA     SQ2
            MOV     C,A
            LDA     M2
            ADC     C
            STA     SQ2

SQM_NOADD:
            ; M <<= 1 (24-bit)
            STC
            CMC
            LDA     M0
            RAL
            STA     M0
            LDA     M1
            RAL
            STA     M1
            LDA     M2
            RAL
            STA     M2

            ; multiplier >>= 1 (16-bit)  WMUL1:WMUL0
            STC
            CMC
            LDA     WMUL1
            RAR
            STA     WMUL1
            LDA     WMUL0
            RAR
            STA     WMUL0

            DCR     B
            JNZ     SQM_LOOP
            RET

;===============================================================================
; MOD24_BY_DIV16  (EXACT)
;   Computes remainder = N mod d
;     N = CAND2:CAND1:CAND0 (24-bit)
;     d = DIVHI:DIVLO      (16-bit, >=3 and odd here)
;   Output:
;     REMHI:REMLO = remainder (16-bit)
;
;   Bitwise restoring division (24 steps):
;     rem = 0
;     for 24 bits:
;       shift N left -> nextbit in CY
;       rem = (rem<<1) | nextbit
;       if rem >= d: rem -= d
;===============================================================================
MOD24_BY_DIV16:
            ; copy dividend to WDIV
            LDA     CAND0
            STA     WDIV0
            LDA     CAND1
            STA     WDIV1
            LDA     CAND2
            STA     WDIV2

            ; rem = 0
            XRA     A
            STA     REMLO
            STA     REMHI

            MVI     B,18H           ; 24 bits

MODL:
            ; shift WDIV left 1, capture MSB in CY
            STC
            CMC
            LDA     WDIV0
            RAL
            STA     WDIV0
            LDA     WDIV1
            RAL
            STA     WDIV1
            LDA     WDIV2
            RAL
            STA     WDIV2
            ; CY now holds the next input bit

            ; rem = (rem<<1) | CY    (16-bit in REMHI:REMLO)
            LDA     REMLO
            RAL
            STA     REMLO
            LDA     REMHI
            RAL
            STA     REMHI

            ; if rem >= divisor then rem -= divisor
            ; compare high first
            LDA     DIVHI
            MOV     C,A             ; C = div_hi
            LDA     REMHI
            CMP     C               ; A(rem_hi) - C(div_hi)
            JC      MODSKIP         ; rem_hi < div_hi
            JNZ     MODSUB          ; rem_hi > div_hi
            ; equal high -> compare low
            LDA     DIVLO
            MOV     C,A             ; C = div_lo
            LDA     REMLO
            CMP     C
            JC      MODSKIP         ; rem_lo < div_lo

MODSUB:
            ; rem -= divisor (16-bit)
            LDA     DIVLO
            MOV     C,A
            LDA     REMLO
            SUB     C
            STA     REMLO

            LDA     DIVHI
            MOV     C,A
            LDA     REMHI
            SBB     C
            STA     REMHI

MODSKIP:
            DCR     B
            JNZ     MODL
            RET

;===============================================================================
; U24_TO_DEC_ASCII  (EXACT)
;   Input:  CAND2:CAND1:CAND0
;   Output: OUTBUF (ASCII digits, no leading zeros), OUTLEN (1..8)
;
;   Max 24-bit value is 16,777,215 (8 digits).
;   Method: repeated subtraction by place values:
;     10,000,000  1,000,000  100,000  10,000  1,000  100  10  1
;===============================================================================
U24_TO_DEC_ASCII:
            ; WORK = CAND
            LDA     CAND0
            STA     WORK0
            LDA     CAND1
            STA     WORK1
            LDA     CAND2
            STA     WORK2

            ; 10,000,000 = 0x00989680
            MVI     H,00H
            MVI     D,98H
            MVI     E,80H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+0

            ; 1,000,000 = 0x000F4240
            MVI     H,00H
            MVI     D,0FH
            MVI     E,40H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+1

            ; 100,000 = 0x000186A0
            MVI     H,00H
            MVI     D,86H
            MVI     E,0A0H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+2

            ; 10,000 = 0x00002710
            MVI     H,00H
            MVI     D,27H
            MVI     E,10H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+3

            ; 1,000 = 0x000003E8
            MVI     H,00H
            MVI     D,03H
            MVI     E,0E8H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+4

            ; 100 = 0x00000064
            MVI     H,00H
            MVI     D,00H
            MVI     E,64H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+5

            ; 10 = 0x0000000A
            MVI     H,00H
            MVI     D,00H
            MVI     E,0AH
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+6

            ; 1 = 0x00000001
            MVI     H,00H
            MVI     D,00H
            MVI     E,01H
            CALL    COUNT_SUB_24
            MOV     A,B
            ADI     '0'
            STA     DIGITS+7

            ; Strip leading zeros into OUTBUF (keep at least 1 digit)
            LXI     H,DIGITS
            MVI     B,08H            ; total digits
STRIP24:
            MOV     A,M
            CPI     '0'
            JNZ     COPY24
            MOV     A,B
            CPI     01H
            JZ      COPY24
            INX     H
            DCR     B
            JMP     STRIP24

COPY24:
            MOV     A,B
            STA     OUTLEN
            LXI     D,OUTBUF
CPY24:
            MOV     A,M
            STAX    D
            INX     H
            INX     D
            DCR     B
            JNZ     CPY24
            RET

;===============================================================================
; COUNT_SUB_24
;   Counts how many times a 24-bit constant can be subtracted from WORK (24-bit).
;   Input:
;     WORK2:WORK1:WORK0 = current remainder
;     H = const_high, D = const_mid, E = const_low
;   Output:
;     B = count (0..9)
;     WORK updated to remainder
;   Clobbers: A,B,C
;===============================================================================
COUNT_SUB_24:
            MVI     B,00H
CS24_LOOP:
            ; Compare WORK >= CONST ? (high, mid, low)
            LDA     WORK2
            CMP     H
            JC      CS24_DONE        ; WORK2 < CONST2
            JNZ     CS24_SUB         ; WORK2 > CONST2
            LDA     WORK1
            CMP     D
            JC      CS24_DONE
            JNZ     CS24_SUB
            LDA     WORK0
            CMP     E
            JC      CS24_DONE

CS24_SUB:
            ; WORK -= CONST
            LDA     WORK0
            SUB     E
            STA     WORK0
            LDA     WORK1
            SBB     D
            STA     WORK1
            LDA     WORK2
            SBB     H
            STA     WORK2

            INR     B
            JMP     CS24_LOOP

CS24_DONE:
            RET

;===============================================================================
; LCD_PUTN
;===============================================================================
LCD_PUTN:
            MOV     A,B
            ORA     A
            RZ
LP1:        MOV     A,M
            CALL    LCD_BYTE_DATA
            INX     H
            DCR     B
            JNZ     LP1
            RET

;===============================================================================
; LCD 4-bit low-level routines (SC719 mapping)
;===============================================================================
LCD_PULSE_E:
            OUT     PORT_LCD
            CALL    DELAY_TINY
            ORI     08H            ; E=1
            OUT     PORT_LCD
            CALL    DELAY_TINY
            ANI     0F7H           ; E=0
            OUT     PORT_LCD
            CALL    DELAY_TINY
            RET

LCD_NIB_CMD:
            ANI     0F0H
            CALL    LCD_PULSE_E
            RET

LCD_NIB_DATA:
            ANI     0F0H
            ORI     04H            ; RS=1
            CALL    LCD_PULSE_E
            RET

LCD_BYTE_CMD:
            PUSH    D
            MOV     D,A

            ANI     0F0H
            CALL    LCD_NIB_CMD

            MOV     A,D
            ANI     00FH
            RLC
            RLC
            RLC
            RLC
            ANI     0F0H
            CALL    LCD_NIB_CMD

            POP     D
            CALL    DELAY_2MS
            RET

LCD_BYTE_DATA:
            PUSH    D
            MOV     D,A

            ANI     0F0H
            CALL    LCD_NIB_DATA

            MOV     A,D
            ANI     00FH
            RLC
            RLC
            RLC
            RLC
            ANI     0F0H
            CALL    LCD_NIB_DATA

            POP     D
            CALL    DELAY_2MS
            RET

LCD_SET_DDRAM:
            ORI     080H
            CALL    LCD_BYTE_CMD
            RET

LCD_CLEAR:
            MVI     A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS
            RET

LCD_INIT_4BIT:
            XRA     A
            OUT     PORT_LCD
            CALL    DELAY_20MS

            ; 8-bit wake-up x3 (0x3 high nibble)
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; switch to 4-bit (0x2 high nibble)
            MVI     A,020H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; function set: 4-bit, 2 lines, 5x8
            MVI     A,028H
            CALL    LCD_BYTE_CMD

            ; display off
            MVI     A,008H
            CALL    LCD_BYTE_CMD

            ; clear
            MVI     A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS

            ; entry mode
            MVI     A,006H
            CALL    LCD_BYTE_CMD

            ; display on
            MVI     A,00CH
            CALL    LCD_BYTE_CMD
            RET

;===============================================================================
; Delays (same style as your sample)
;===============================================================================
DELAY_TINY:
            PUSH    B
            MVI     B,12H
DT1:        DCR     B
            JNZ     DT1
            POP     B
            RET

DELAY_2MS:
            PUSH    B
            PUSH    D
            MVI     B,08H
D2A:        MVI     D,0FFH
D2B:        DCR     D
            JNZ     D2B
            DCR     B
            JNZ     D2A
            POP     D
            POP     B
            RET

DELAY_10MS:
            PUSH    B
            MVI     B,05H
D10:        CALL    DELAY_2MS
            DCR     B
            JNZ     D10
            POP     B
            RET

DELAY_20MS:
            PUSH    B
            MVI     B,0AH
D20:        CALL    DELAY_2MS
            DCR     B
            JNZ     D20
            POP     B
            RET

DELAY_60MS:
            PUSH    B
            MVI     B,1EH
D60:        CALL    DELAY_2MS
            DCR     B
            JNZ     D60
            POP     B
            RET

;===============================================================================
; Data / buffers / stack
;===============================================================================
; 24-bit candidate (little-endian)
CAND0:       DB      02H
CAND1:       DB      00H
CAND2:       DB      00H

; current divisor d (16-bit)
DIVLO:       DB      03H
DIVHI:       DB      00H

; square bytes (24-bit)
SQ0:         DB      00H
SQ1:         DB      00H
SQ2:         DB      00H

; multiply working
M0:          DB      00H
M1:          DB      00H
M2:          DB      00H
WMUL0:       DB      00H
WMUL1:       DB      00H

; modulus working
WDIV0:       DB      00H
WDIV1:       DB      00H
WDIV2:       DB      00H
REMLO:       DB      00H
REMHI:       DB      00H

; decimal conversion working
WORK0:       DB      00H
WORK1:       DB      00H
WORK2:       DB      00H
DIGITS:      DB      '0','0','0','0','0','0','0','0'  ; up to 8 digits
OUTLEN:      DB      01H
OUTBUF:      DB      '0','0','0','0','0','0','0','0'

STACK:       DS      80
STACKEND:

            END     START
