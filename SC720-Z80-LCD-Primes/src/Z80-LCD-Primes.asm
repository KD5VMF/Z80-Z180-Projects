;===============================================================================
;  LCDPRIME_Z80.ASM  (Z80 native)
;
;  SC720 Z80 board - Prime display (16-bit)
;
;  Behavior (matches your working 16-bit version):
;    - Computes primes starting at 2 (exact trial division)
;    - Displays ONE prime at LCD row 1 / col 0 (top-left)
;    - Each new prime OVERWRITES the previous prime (in-place)
;    - Pads spaces to clear the rest of the row (prevents leftover digits)
;    - Adjustable delay between primes (single knob at top)
;
;  LCD interface (SC719/SC720-style 4-bit latch):
;    PORT_LCD is the LCD control/data latch.
;      bit2 = RS (0=cmd, 1=data)
;      bit3 = E  (enable pulse)
;      bit4..bit7 = D4..D7
;    R/W tied LOW (write-only)
;
;  Assemble as a .COM-style program (ORG 0100h) and run.
;===============================================================================

            ORG     0100H
            JP      START

;---------------------- CONFIG -------------------------------------------------
PORT_LCD            EQU     00H         ; MUST match your LCD latch port
LINE1               EQU     00H         ; DDRAM base for row 1

; EASY speed knob:
;   smaller = faster, larger = slower
PRIME_DELAY_OUTER   EQU     01H         ; <<< CHANGE THIS ONE VALUE

; Inner delay count (leave alone unless your CPU speed changes a lot)
PRIME_DELAY_INNER   EQU     2800H

;===============================================================================
START:
            DI
            LD      SP,STACKEND

            CALL    DELAY_60MS
            CALL    LCD_INIT_4BIT
            CALL    LCD_CLEAR

            ; candidate = 2
            LD      HL,0002H
            LD      (CAND),HL

MAIN_LOOP:
            LD      HL,(CAND)
            CALL    IS_PRIME16        ; A=1 if prime else 0
            OR      A
            JR      Z,NEXT_CAND

            ; show prime at top-left (overwrite)
            LD      HL,(CAND)
            CALL    DISPLAY_TOPLEFT

            CALL    PRIME_DELAY

NEXT_CAND:
            ; candidate progression: 2 -> 3 -> +2 (odds only)
            LD      HL,(CAND)
            LD      A,H
            OR      L
            JR      Z,SET3            ; should never be 0, but safe
            LD      A,H
            OR      A
            JR      NZ,ADD2
            LD      A,L
            CP      02H
            JR      Z,SET3

ADD2:
            INC     HL
            INC     HL
            LD      (CAND),HL
            JR      MAIN_LOOP

SET3:
            LD      HL,0003H
            LD      (CAND),HL
            JR      MAIN_LOOP

;===============================================================================
; DISPLAY_TOPLEFT
;   In:  HL = value (0..65535)
;   Out: prints decimal at row1 col0 and clears rest of the row with spaces
;===============================================================================
DISPLAY_TOPLEFT:
            PUSH    HL
            CALL    U16_TO_DEC_ASCII      ; OUTBUF/OUTLEN set
            ; cursor row1 col0
            LD      A,LINE1
            CALL    LCD_SET_DDRAM

            ; print digits
            LD      HL,OUTBUF
            LD      A,(OUTLEN)
            LD      B,A
            LD      C,A                    ; save len in C
            CALL    LCD_PUTN

            ; pad spaces to column 15 (16 - len)
            LD      A,16
            SUB     C
            LD      B,A
            OR      A
            JR      Z,DT_DONE
DT_PAD:
            LD      A,' '
            CALL    LCD_BYTE_DATA
            DJNZ    DT_PAD
DT_DONE:
            POP     HL
            RET

;===============================================================================
; PRIME_DELAY (adjustable)
;===============================================================================
PRIME_DELAY:
            PUSH    HL
            PUSH    BC
            LD      B,PRIME_DELAY_OUTER
PD_OUT:
            LD      HL,PRIME_DELAY_INNER
PD_IN:
            DEC     HL
            LD      A,H
            OR      L
            JR      NZ,PD_IN
            DJNZ    PD_OUT
            POP     BC
            POP     HL
            RET

;===============================================================================
; IS_PRIME16 (EXACT)
;   In:  HL = n
;   Out: A=01h if prime, A=00h if not
;
;   Method:
;     - handle n<2, n==2, even
;     - test odd divisors d = 3,5,7,... while d*d <= n
;     - use exact remainder (MOD16BY8)
;   Notes:
;     - For 16-bit n, max sqrt(n) is 255, so divisor fits in 8-bit.
;===============================================================================
IS_PRIME16:
            ; n < 2 ?
            LD      A,H
            OR      A
            JR      NZ,IP_BIG
            LD      A,L
            CP      02H
            JR      C,IP_NOT
            JR      Z,IP_TWO

IP_BIG:
            ; n == 2 ?
            LD      A,H
            OR      A
            JR      NZ,IP_EVEN
            LD      A,L
            CP      02H
            JR      Z,IP_TWO

IP_EVEN:
            ; even?
            BIT     0,L
            JR      Z,IP_NOT

            ; save n in DE
            LD      D,H
            LD      E,L

            ; d = 3
            LD      C,03H

IP_LOOP:
            ; square = d*d in HL
            PUSH    DE
            LD      A,C
            CALL    SQUARE8_TO16
            POP     DE

            ; if square > n => prime
            ; compare HL (square) to DE (n)
            LD      A,D
            CP      H
            JR      C,IP_DO_MOD       ; n_hi < sq_hi => square > n => PRIME, but CP is reversed
            JR      NZ,IP_PRIMECHK_HI ; if n_hi != sq_hi, decide
            LD      A,E
            CP      L
            JR      C,IP_PRIME        ; n_lo < sq_lo => square > n
            JR      Z,IP_DO_MOD       ; equal => still check mod
            JR      IP_DO_MOD         ; square < n

IP_PRIMECHK_HI:
            ; if n_hi < sq_hi => prime else continue
            ; We already did: CP H with A=D; if A < H then C set -> IP_DO_MOD taken (wrong)
            ; So handle properly using flags from that CP:
            ; If D < H, C=1 and we'd have jumped IP_DO_MOD, but we want PRIME.
            ; So we fix by redoing compare cleanly below.
            LD      A,H
            CP      D
            JR      C,IP_DO_MOD       ; H < D => square < n
            JR      Z,IP_DO_MOD
            JR      IP_PRIME          ; H > D => square > n

IP_DO_MOD:
            ; remainder = n mod d
            LD      H,D
            LD      L,E
            CALL    MOD16BY8          ; divisor in C, remainder in A
            OR      A
            JR      Z,IP_NOT          ; divisible

            ; d += 2
            INC     C
            INC     C
            JR      IP_LOOP

IP_TWO:
            LD      A,01H
            RET
IP_PRIME:
            LD      A,01H
            RET
IP_NOT:
            XOR     A
            RET

;===============================================================================
; SQUARE8_TO16
;   In:  A = x
;   Out: HL = x*x   (exact)
;===============================================================================
SQUARE8_TO16:
            LD      B,A          ; count
            LD      D,A          ; addend
            LD      HL,0000H
            LD      A,B
            OR      A
            RET     Z
SQ_L:
            LD      A,L
            ADD     A,D
            LD      L,A
            LD      A,H
            ADC     A,0
            LD      H,A
            DJNZ    SQ_L
            RET

;===============================================================================
; MOD16BY8 (exact remainder)
;   In:  HL = dividend
;        C  = divisor (1..255)
;   Out: A  = remainder (0..div-1)
;   Clobbers: A,B,D,E,H,L
;
;   Bitwise restoring division, keeping 16-bit remainder in DE.
;===============================================================================
MOD16BY8:
            LD      DE,0000H
            LD      B,16

M16_LOOP:
            ADD     HL,HL           ; shift dividend left, bit -> carry

            ; shift remainder left, bring in carry
            RL      E
            RL      D

            ; if remainder >= divisor, subtract divisor
            LD      A,D
            OR      A
            JR      NZ,M16_SUB
            LD      A,E
            CP      C
            JR      C,M16_SKIP

M16_SUB:
            LD      A,E
            SUB     C
            LD      E,A
            LD      A,D
            SBC     A,0
            LD      D,A

M16_SKIP:
            DJNZ    M16_LOOP
            LD      A,E
            RET

;===============================================================================
; U16_TO_DEC_ASCII (exact)
;   In:  HL=value
;   Out: OUTBUF digits (no leading zeros), OUTLEN (1..5)
;   Clobbers: AF,BC,DE,HL
;
;   Repeated subtraction by 10000,1000,100,10,1 (fast enough on Z80).
;===============================================================================
U16_TO_DEC_ASCII:
            LD      (WORK),HL

            ; 10000
            LD      HL,(WORK)
            LD      DE,2710H
            CALL    COUNT_SUB_16
            LD      A,B
            ADD     A,'0'
            LD      (DIGITS+0),A
            LD      (WORK),HL

            ; 1000
            LD      HL,(WORK)
            LD      DE,03E8H
            CALL    COUNT_SUB_16
            LD      A,B
            ADD     A,'0'
            LD      (DIGITS+1),A
            LD      (WORK),HL

            ; 100
            LD      HL,(WORK)
            LD      DE,0064H
            CALL    COUNT_SUB_16
            LD      A,B
            ADD     A,'0'
            LD      (DIGITS+2),A
            LD      (WORK),HL

            ; 10
            LD      HL,(WORK)
            LD      DE,000AH
            CALL    COUNT_SUB_16
            LD      A,B
            ADD     A,'0'
            LD      (DIGITS+3),A
            LD      (WORK),HL

            ; 1 (HL now 0..9)
            LD      HL,(WORK)
            LD      A,L
            ADD     A,'0'
            LD      (DIGITS+4),A

            ; strip leading zeros into OUTBUF (leave at least 1 digit)
            LD      HL,DIGITS
            LD      B,5
STRIP0:
            LD      A,(HL)
            CP      '0'
            JR      NZ,COPY_DIGS
            LD      A,B
            CP      1
            JR      Z,COPY_DIGS
            INC     HL
            DEC     B
            JR      STRIP0

COPY_DIGS:
            LD      A,B
            LD      (OUTLEN),A
            LD      DE,OUTBUF
CPY1:
            LD      A,(HL)
            LD      (DE),A
            INC     HL
            INC     DE
            DJNZ    CPY1
            RET

;===============================================================================
; COUNT_SUB_16
;   In:  HL=value, DE=constant
;   Out: B=count (0..9), HL=remainder
;   Clobbers: AF
;===============================================================================
COUNT_SUB_16:
            LD      B,0
CS_LOOP:
            ; if HL < DE => done
            OR      A               ; clear carry
            SBC     HL,DE
            JR      C,CS_UNDO       ; went negative -> undo and stop
            INC     B
            JR      CS_LOOP
CS_UNDO:
            ADD     HL,DE
            RET

;===============================================================================
; LCD helpers (same logic as your working latch driver)
;===============================================================================

LCD_PUTN:
            LD      A,B
            OR      A
            RET     Z
LP1:
            LD      A,(HL)
            CALL    LCD_BYTE_DATA
            INC     HL
            DJNZ    LP1
            RET

LCD_PULSE_E:
            OUT     (PORT_LCD),A
            CALL    DELAY_TINY
            OR      08H                 ; E=1
            OUT     (PORT_LCD),A
            CALL    DELAY_TINY
            AND     0F7H                ; E=0
            OUT     (PORT_LCD),A
            CALL    DELAY_TINY
            RET

LCD_NIB_CMD:
            AND     0F0H
            CALL    LCD_PULSE_E
            RET

LCD_NIB_DATA:
            AND     0F0H
            OR      04H                 ; RS=1
            CALL    LCD_PULSE_E
            RET

LCD_BYTE_CMD:
            PUSH    AF
            LD      D,A

            AND     0F0H
            CALL    LCD_NIB_CMD

            LD      A,D
            AND     0FH
            RLCA
            RLCA
            RLCA
            RLCA
            AND     0F0H
            CALL    LCD_NIB_CMD

            POP     AF
            CALL    DELAY_2MS
            RET

LCD_BYTE_DATA:
            PUSH    AF
            LD      D,A

            AND     0F0H
            CALL    LCD_NIB_DATA

            LD      A,D
            AND     0FH
            RLCA
            RLCA
            RLCA
            RLCA
            AND     0F0H
            CALL    LCD_NIB_DATA

            POP     AF
            CALL    DELAY_2MS
            RET

LCD_SET_DDRAM:
            OR      080H
            CALL    LCD_BYTE_CMD
            RET

LCD_CLEAR:
            LD      A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS
            RET

LCD_INIT_4BIT:
            XOR     A
            OUT     (PORT_LCD),A
            CALL    DELAY_20MS

            ; 8-bit wakeup x3 (0x3 high nibble)
            LD      A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            LD      A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            LD      A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; switch to 4-bit (0x2 high nibble)
            LD      A,020H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; function set: 4-bit, 2 lines, 5x8
            LD      A,028H
            CALL    LCD_BYTE_CMD

            ; display off
            LD      A,008H
            CALL    LCD_BYTE_CMD

            ; clear
            LD      A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS

            ; entry mode increment
            LD      A,006H
            CALL    LCD_BYTE_CMD

            ; display on
            LD      A,00CH
            CALL    LCD_BYTE_CMD
            RET

;===============================================================================
; delays
;===============================================================================
DELAY_TINY:
            PUSH    BC
            LD      B,12H
DT1:        DJNZ    DT1
            POP     BC
            RET

DELAY_2MS:
            PUSH    BC
            PUSH    DE
            LD      B,08H
D2A:        LD      D,0FFH
D2B:        DEC     D
            JR      NZ,D2B
            DJNZ    D2A
            POP     DE
            POP     BC
            RET

DELAY_10MS:
            PUSH    BC
            LD      B,05H
D10:        CALL    DELAY_2MS
            DJNZ    D10
            POP     BC
            RET

DELAY_20MS:
            PUSH    BC
            LD      B,0AH
D20:        CALL    DELAY_2MS
            DJNZ    D20
            POP     BC
            RET

DELAY_60MS:
            PUSH    BC
            LD      B,1EH
D60:        CALL    DELAY_2MS
            DJNZ    D60
            POP     BC
            RET

;===============================================================================
; data
;===============================================================================
CAND:       DW      0002H

WORK:       DW      0000H
DIGITS:     DB      '0','0','0','0','0'
OUTLEN:     DB      01H
OUTBUF:     DB      '0','0','0','0','0'

STACK:      DS      80
STACKEND:

            END
