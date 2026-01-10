;===============================================================================
;  LCDPRIME6.ASM  (8080 / 8085 compatible, runs on Z80 too)
;
;  SC720 Z80 board - FAST prime display (single value, overwrites in place)
;
;  What you asked for:
;    - Print primes starting at 2
;    - ALWAYS write at top-left (row 1, col 0)
;    - Each new prime OVERWRITES the previous one (not "2 3 5 7..." across)
;    - Small adjustable wait (so it updates fast, but not a blur)
;
;  LCD interface matches your working sample (SC719/SC720 style 4-bit latch):
;    PORT_LCD is the LCD control/data latch.
;      bit2 = RS  (0=command, 1=data)
;      bit3 = E   (enable pulse)
;      bit4-7 = D4-D7 (4-bit data bus)
;    R/W tied low (write-only)
;
;  Notes:
;    - After printing the number, we write spaces out to column 15 so old digits
;      are erased when digit-count increases (e.g., 97 -> 101).
;    - Prime test is exact (trial division with exact remainder).
;===============================================================================

            ORG     0100H
            JMP     START

;---------------------- CONFIG -------------------------------------------------
PORT_LCD    EQU     00H            ; MUST match your working LCD program port
LINE1       EQU     00H            ; DDRAM base for row 1 (HD44780)

; Speed control (EASY ADJUST):
;   Smaller = faster updates, larger = slower.
;   Recommended starting points:
;     01h..08h  (very fast)
;     10h..30h  (moderate)
PRIME_DELAY_OUTER EQU 01H          ; <<< CHANGE THIS (main knob)

; Inner loop constant (leave this alone unless you change CPU speed a lot)
PRIME_DELAY_INNER EQU 4000H

;===============================================================================
START:
            DI
            LXI     SP,STACKEND

            CALL    DELAY_60MS
            CALL    LCD_INIT_4BIT
            CALL    LCD_CLEAR

            ; Start at 2
            LXI     H,0002H
            SHLD    CAND

MAIN_LOOP:
            ; HL = candidate
            LHLD    CAND

            ; Prime?
            CALL    IS_PRIME
            ORA     A
            JZ      NEXT_CAND

            ; Display this prime at row1 col0 (overwrite prior)
            LHLD    CAND
            CALL    DISPLAY_PRIME_TOPLEFT

            ; Small wait so you can see it (adjust at top)
            CALL    PRIME_DELAY

NEXT_CAND:
            ; candidate progression: 2,3,5,7,9... (skip even numbers)
            LHLD    CAND
            MOV     A,H
            ORA     A
            JNZ     ADD2
            MOV     A,L
            CPI     02H
            JZ      TO3

ADD2:       INX     H
            INX     H
            SHLD    CAND
            JMP     MAIN_LOOP

TO3:        LXI     H,0003H
            SHLD    CAND
            JMP     MAIN_LOOP

;===============================================================================
; DISPLAY_PRIME_TOPLEFT
;   Input: HL = prime
;   Output: prints the prime at row1 col0, and pads spaces to clear rest of row
;===============================================================================
DISPLAY_PRIME_TOPLEFT:
            ; Convert HL -> OUTBUF/OUTLEN
            CALL    U16_TO_DEC_ASCII

            ; Set cursor row1 col0
            MVI     A,LINE1
            CALL    LCD_SET_DDRAM

            ; Print digits
            LXI     H,OUTBUF
            LDA     OUTLEN
            MOV     C,A              ; C = len (save)
            MOV     B,A              ; B = len (for LCD_PUTN)
            CALL    LCD_PUTN

            ; Pad spaces to end of row (16 - len)
            MVI     A,10H            ; 16 columns
            SUB     C
            MOV     B,A
            MOV     A,B
            ORA     A
            RZ

PAD_LOOP:
            MVI     A,' '
            CALL    LCD_BYTE_DATA
            DCR     B
            JNZ     PAD_LOOP
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
; IS_PRIME  (EXACT)
;   Input:  HL = n (0..65535)
;   Output: A = 01h if prime, 00h if not prime
;===============================================================================
IS_PRIME:
            ; n < 2?
            MOV     A,H
            ORA     A
            JNZ     IP_BIG
            MOV     A,L
            CPI     02H
            JC      IP_NOT
            JZ      IP_TWO

IP_BIG:
            ; n==2?
            MOV     A,H
            ORA     A
            JNZ     IP_EVEN
            MOV     A,L
            CPI     02H
            JZ      IP_TWO

IP_EVEN:
            ; even?
            MOV     A,L
            ANI     01H
            JZ      IP_NOT

            ; Save n in DE
            MOV     D,H
            MOV     E,L

            ; d = 3,5,7,... in C
            MVI     C,03H

IP_LOOP:
            ; square = d*d in HL (preserve DE)
            PUSH    D
            MOV     A,C
            CALL    SQUARE8_TO16     ; HL = d*d
            POP     D

            ; If square > n => prime
            MOV     A,H
            CMP     D
            JC      IP_MOD
            JNZ     IP_PRIME
            MOV     A,L
            CMP     E
            JC      IP_MOD
            JZ      IP_MOD
            JMP     IP_PRIME

IP_MOD:
            ; remainder = n mod d
            MOV     H,D
            MOV     L,E
            CALL    MOD16BY8         ; divisor in C, remainder in A
            ORA     A
            JZ      IP_NOT

            ; d += 2
            INR     C
            INR     C
            JMP     IP_LOOP

IP_TWO:     MVI     A,01H
            RET
IP_PRIME:   MVI     A,01H
            RET
IP_NOT:     XRA     A
            RET

;===============================================================================
; SQUARE8_TO16  (EXACT)
;   Input:  A=x
;   Output: HL = x*x
;===============================================================================
SQUARE8_TO16:
            MOV     B,A              ; loop count
            MOV     D,A              ; addend
            LXI     H,0000H
            MOV     A,B
            ORA     A
            RZ
SQ_L:
            MOV     A,L
            ADD     D
            MOV     L,A
            MOV     A,H
            ACI     00H
            MOV     H,A
            DCR     B
            JNZ     SQ_L
            RET

;===============================================================================
; MOD16BY8  (EXACT remainder)
;   Input:  HL = dividend
;           C  = divisor (1..255)
;   Output: A  = remainder
;===============================================================================
MOD16BY8:
            ; remainder DE = 0
            MVI     D,00H
            MVI     E,00H
            MVI     B,10H            ; 16 bits

M16L:
            ; shift dividend left, CY = next bit
            DAD     H

            ; shift remainder left, bring in CY
            MOV     A,E
            RAL
            MOV     E,A
            MOV     A,D
            RAL
            MOV     D,A

            ; if remainder >= divisor, subtract divisor
            MOV     A,D
            ORA     A
            JNZ     M16SUB
            MOV     A,E
            CMP     C
            JC      M16NOS

M16SUB:
            MOV     A,E
            SUB     C
            MOV     E,A
            MOV     A,D
            SBI     00H
            MOV     D,A

M16NOS:
            DCR     B
            JNZ     M16L

            MOV     A,E
            RET

;===============================================================================
; U16_TO_DEC_ASCII (EXACT, robust)
;   Input: HL=value
;   Output: OUTBUF digits, OUTLEN
;===============================================================================
U16_TO_DEC_ASCII:
            SHLD    WORK

            ; 10000
            LHLD    WORK
            LXI     D,2710H
            CALL    COUNT_SUB_16
            MOV     A,B
            ADI     '0'
            STA     DIGITS+0
            SHLD    WORK

            ; 1000
            LHLD    WORK
            LXI     D,03E8H
            CALL    COUNT_SUB_16
            MOV     A,B
            ADI     '0'
            STA     DIGITS+1
            SHLD    WORK

            ; 100
            LHLD    WORK
            LXI     D,0064H
            CALL    COUNT_SUB_16
            MOV     A,B
            ADI     '0'
            STA     DIGITS+2
            SHLD    WORK

            ; 10
            LHLD    WORK
            LXI     D,000AH
            CALL    COUNT_SUB_16
            MOV     A,B
            ADI     '0'
            STA     DIGITS+3
            SHLD    WORK

            ; 1
            LHLD    WORK
            MOV     A,L
            ADI     '0'
            STA     DIGITS+4

            ; strip leading zeros (leave at least 1 digit)
            LXI     H,DIGITS
            MVI     B,05H
STRIP0:
            MOV     A,M
            CPI     '0'
            JNZ     COPY_DIGS
            MOV     A,B
            CPI     01H
            JZ      COPY_DIGS
            INX     H
            DCR     B
            JMP     STRIP0

COPY_DIGS:
            MOV     A,B
            STA     OUTLEN
            LXI     D,OUTBUF
CPY1:
            MOV     A,M
            STAX    D
            INX     H
            INX     D
            DCR     B
            JNZ     CPY1
            RET

;===============================================================================
; COUNT_SUB_16
;   Input:  HL=value, DE=constant
;   Output: B = count, HL=remainder
;===============================================================================
COUNT_SUB_16:
            MVI     B,00H
CS_LOOP:
            MOV     A,H
            CMP     D
            JC      CS_DONE
            JNZ     CS_SUB
            MOV     A,L
            CMP     E
            JC      CS_DONE

CS_SUB:
            MOV     A,L
            SUB     E
            MOV     L,A
            MOV     A,H
            SBB     D
            MOV     H,A
            INR     B
            JMP     CS_LOOP

CS_DONE:
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
; LCD 4-bit low-level routines (matches your working sample)
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
; Delays
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
CAND:        DW      0002H
WORK:        DW      0000H
DIGITS:      DB      '0','0','0','0','0'
OUTLEN:      DB      01H
OUTBUF:      DB      '0','0','0','0','0'

STACK:       DS      80
STACKEND:

            END     START
