;===============================================================================
;  SC719_LCD_RTC_Clock.asm
;
;  A tiny real-time clock display for RomWBW / HBIOS systems using an SC719
;  HD44780-compatible 16x2 LCD interface in 4-bit mode.
;
;  Displays:
;    Line 1 (centered):  HH:MM:SS   (blinking colons)
;    Line 2 (centered):  20YY-MM-DD
;
;  Hardware assumptions (SC719 style LCD port):
;    PORT_LCD (default 00h) is the LCD control/data latch.
;      bit2 = RS  (0=command, 1=data)
;      bit3 = E   (enable pulse)
;      bit4-7 = D4-D7 (4-bit data bus)
;      R/W is tied low (write-only)
;
;  Software assumptions (RomWBW HBIOS):
;    RTCGETTIM is called via:
;      B  = 20h
;      HL = buffer (6 bytes)
;      RST 1
;
;    Buffer returns (BCD):
;      [0]=YY  [1]=MM  [2]=DD  [3]=HH  [4]=MM  [5]=SS
;
;  Assemble to a .COM style program (ORG 0100h), then run.
;
;  Notes:
;    - Delay loops are "crude" and depend on CPU speed. If LCD init is flaky,
;      increase delays.
;    - We only refresh the LCD when seconds change (less flicker, less bus spam).
;===============================================================================

            ORG     0100H
            JMP     START

;---------------------- CONFIG -------------------------------------------------
PORT_LCD    EQU     00H            ; SC719 base address (JP1 = 00h)

; Centered positions on 16x2:
;   "HH:MM:SS" = 8 chars, centered => column 4 (0-based) on line 1
;   "20YY-MM-DD" = 10 chars, centered => column 3 on line 2
;
; HD44780 DDRAM:
;   line1 starts at 00h
;   line2 starts at 40h
TIME_POS    EQU     04H            ; line1 col4
DATE_POS    EQU     43H            ; line2 col3 (40h + 03h)

;===============================================================================
START:
            DI
            LXI     SP,STACKEND

            ; Initialize variables
            XRA     A
            STA     BLINK          ; 0/1 toggles each second for blinking ':'
            MVI     A,0FFH
            STA     PREV_SEC       ; previous seconds (init to impossible value)

            ; LCD initialization sequence
            CALL    DELAY_60MS     ; give LCD power-up time
            CALL    LCD_INIT_4BIT  ; put LCD in 4-bit mode, clear, etc.
            CALL    LCD_CLEAR

MAIN:
            ; Read RTC into TIMBUF (BCD)
            CALL    READRTC

            ; Only update if seconds changed
            LDA     TIMBUF+5       ; SS
            MOV     D,A
            LDA     PREV_SEC
            CMP     D
            JZ      IDLE

            MOV     A,D
            STA     PREV_SEC

            ; Flip blink flag for ':' characters
            CALL    TOGGLE_BLINK

            ; Build strings for display
            CALL    BUILD_TIME
            CALL    BUILD_DATE

            ; Write time string (8 chars)
            MVI     A,TIME_POS
            CALL    LCD_SET_DDRAM
            LXI     H,TIME_STR
            MVI     B,08H
            CALL    LCD_PUTN

            ; Write date string (10 chars)
            MVI     A,DATE_POS
            CALL    LCD_SET_DDRAM
            LXI     H,DATE_STR
            MVI     B,0AH
            CALL    LCD_PUTN

IDLE:
            ; Small idle delay to avoid hammering RTC/HBIOS
            CALL    SHORTDLY
            JMP     MAIN

;===============================================================================
; READRTC
;   RomWBW HBIOS RTCGETTIM
;     B = 20h
;     HL = TIMBUF
;     RST 1
;   Returns YY,MM,DD,HH,MM,SS in BCD into TIMBUF[0..5].
;===============================================================================
READRTC:
            LXI     H,TIMBUF
            MVI     B,020H
            RST     1
            RET

;===============================================================================
; BUILD_TIME
;   Creates TIME_STR = "HH:MM:SS"
;   The ':' characters blink on/off each second.
;===============================================================================
BUILD_TIME:
            ; HH
            LDA     TIMBUF+3
            CALL    BCD2ASC
            MOV     A,H
            STA     TIME_STR+0
            MOV     A,L
            STA     TIME_STR+1

            ; First colon: ':' or ' ' depending on BLINK
            LDA     BLINK
            ANI     01H
            JZ      BT_COL_SPACE
            MVI     A,':'
            JMP     BT_COL_SET
BT_COL_SPACE:
            MVI     A,' '
BT_COL_SET:
            STA     TIME_STR+2

            ; MM
            LDA     TIMBUF+4
            CALL    BCD2ASC
            MOV     A,H
            STA     TIME_STR+3
            MOV     A,L
            STA     TIME_STR+4

            ; Second colon matches first
            LDA     TIME_STR+2
            STA     TIME_STR+5

            ; SS
            LDA     TIMBUF+5
            CALL    BCD2ASC
            MOV     A,H
            STA     TIME_STR+6
            MOV     A,L
            STA     TIME_STR+7
            RET

;===============================================================================
; BUILD_DATE
;   Creates DATE_STR = "20YY-MM-DD"
;===============================================================================
BUILD_DATE:
            MVI     A,'2'
            STA     DATE_STR+0
            MVI     A,'0'
            STA     DATE_STR+1

            ; YY
            LDA     TIMBUF+0
            CALL    BCD2ASC
            MOV     A,H
            STA     DATE_STR+2
            MOV     A,L
            STA     DATE_STR+3

            MVI     A,'-'
            STA     DATE_STR+4

            ; MM
            LDA     TIMBUF+1
            CALL    BCD2ASC
            MOV     A,H
            STA     DATE_STR+5
            MOV     A,L
            STA     DATE_STR+6

            MVI     A,'-'
            STA     DATE_STR+7

            ; DD
            LDA     TIMBUF+2
            CALL    BCD2ASC
            MOV     A,H
            STA     DATE_STR+8
            MOV     A,L
            STA     DATE_STR+9
            RET

;===============================================================================
; TOGGLE_BLINK
;   BLINK ^= 1
;===============================================================================
TOGGLE_BLINK:
            LDA     BLINK
            XRI     01H
            STA     BLINK
            RET

;===============================================================================
; BCD2ASC
;   Input:  A = packed BCD (e.g., 0x25 = "25")
;   Output: H = ASCII tens, L = ASCII ones
;===============================================================================
BCD2ASC:
            MOV     D,A
            ANI     00FH           ; low nibble = ones
            ADI     '0'
            MOV     L,A

            MOV     A,D
            ANI     0F0H           ; high nibble = tens
            RRC
            RRC
            RRC
            RRC
            ADI     '0'
            MOV     H,A
            RET

;===============================================================================
; LCD_PUTN
;   Print B bytes from [HL] as LCD data bytes.
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
;   bit2=RS, bit3=E, bits4-7=D4-D7
;===============================================================================

; Pulse the Enable line (E) to latch current nibble into LCD
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

; Send an upper nibble as a command (RS=0)
LCD_NIB_CMD:
            ANI     0F0H           ; keep D4-D7, clear RS/E
            CALL    LCD_PULSE_E
            RET

; Send an upper nibble as data (RS=1)
LCD_NIB_DATA:
            ANI     0F0H
            ORI     04H            ; RS=1
            CALL    LCD_PULSE_E
            RET

; Send a full 8-bit command in two nibbles
LCD_BYTE_CMD:
            PUSH    D
            MOV     D,A

            ANI     0F0H
            CALL    LCD_NIB_CMD

            MOV     A,D
            ANI     00FH           ; move low nibble into high nibble
            RLC
            RLC
            RLC
            RLC
            ANI     0F0H
            CALL    LCD_NIB_CMD

            POP     D
            CALL    DELAY_2MS      ; safe wait for most commands
            RET

; Send a full 8-bit data byte in two nibbles
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

; Set LCD cursor via DDRAM address (A = address)
LCD_SET_DDRAM:
            ORI     080H
            CALL    LCD_BYTE_CMD
            RET

; Clear LCD display
LCD_CLEAR:
            MVI     A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS     ; clear needs longer delay
            RET

; Put LCD into 4-bit mode and configure 2-line display
LCD_INIT_4BIT:
            XRA     A
            OUT     PORT_LCD
            CALL    DELAY_20MS

            ; HD44780 8-bit wake-up sequence:
            ; send high nibble 0x3 three times (still in unknown state)
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; switch to 4-bit mode (send high nibble 0x2)
            MVI     A,020H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; function set: 4-bit, 2 lines, 5x8 font
            MVI     A,028H
            CALL    LCD_BYTE_CMD

            ; display off
            MVI     A,008H
            CALL    LCD_BYTE_CMD

            ; clear
            MVI     A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS

            ; entry mode: increment, no shift
            MVI     A,006H
            CALL    LCD_BYTE_CMD

            ; display on, cursor off, blink off
            MVI     A,00CH
            CALL    LCD_BYTE_CMD
            RET

;===============================================================================
; Crude delay loops (tweak if needed for your CPU speed)
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

; Light throttle delay between polls
SHORTDLY:
            LXI     H,2000H
SD1:        DCX     H
            MOV     A,H
            ORA     L
            JNZ     SD1
            RET

;===============================================================================
; Data + stack
;===============================================================================
TIMBUF:      DS      6              ; YY MM DD HH MM SS (BCD)
TIME_STR:    DS      8              ; "HH:MM:SS"
DATE_STR:    DS      10             ; "20YY-MM-DD"
PREV_SEC:    DB      00H            ; previous seconds (BCD)
BLINK:       DB      00H            ; 0/1 toggles each second

STACK:       DS      80
STACKEND:

            END     START
