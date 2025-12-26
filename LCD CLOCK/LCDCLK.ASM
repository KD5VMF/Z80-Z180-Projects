            ORG     0100H
            JMP     START

; ---------------- CONFIG ----------------
PORT_LCD    EQU     00H            ; SC719 base address (JP1 = 00h)

; Centered positions on 16x2:
; "HH:MM:SS" (8 chars) -> col 4
; "20YY-MM-DD" (10 chars) -> col 3
TIME_POS    EQU     04H            ; row1 col4
DATE_POS    EQU     43H            ; row2 col3 (0x40 + 3)

; ============================================================
START:
            DI
            LXI     SP,STACKEND

            ; Init vars
            XRA     A
            STA     BLINK
            MVI     A,0FFH
            STA     PREV_SEC

            ; LCD init
            CALL    DELAY_60MS
            CALL    LCD_INIT_4BIT
            CALL    LCD_CLEAR

MAIN:
            CALL    READRTC

            ; update only when seconds changes
            LDA     TIMBUF+5
            MOV     D,A
            LDA     PREV_SEC
            CMP     D
            JZ      IDLE

            MOV     A,D
            STA     PREV_SEC

            ; toggle blink flag + heartbeat LED (bit0 only)
            CALL    TOGGLE_BLINK
            CALL    TOGGLE_LED0

            CALL    BUILD_TIME
            CALL    BUILD_DATE

            ; write time (overwrite only these chars)
            MVI     A,TIME_POS
            CALL    LCD_SET_DDRAM
            LXI     H,TIME_STR
            MVI     B,08H
            CALL    LCD_PUTN

            ; write date
            MVI     A,DATE_POS
            CALL    LCD_SET_DDRAM
            LXI     H,DATE_STR
            MVI     B,0AH
            CALL    LCD_PUTN

IDLE:
            CALL    SHORTDLY
            JMP     MAIN

; ============================================================
; RomWBW HBIOS RTCGETTIM
;   B=20h, HL=buffer, RST 1
;   returns YY,MM,DD,HH,MM,SS (BCD) into TIMBUF[0..5]
; (same as your gCLOCK.ASM) :contentReference[oaicite:1]{index=1}
; ============================================================
READRTC:
            LXI     H,TIMBUF
            MVI     B,020H
            RST     1
            RET

; ============================================================
; Build "HH:MM:SS" (with blinking ':' every other tick)
; ============================================================
BUILD_TIME:
            ; HH
            LDA     TIMBUF+3
            CALL    BCD2ASC
            MOV     A,H
            STA     TIME_STR+0
            MOV     A,L
            STA     TIME_STR+1

            ; colon based on BLINK
            LDA     BLINK
            ANI     01H
            JZ      CT_SPACE
            MVI     A,':'
            JMP     CT_SET
CT_SPACE:   MVI     A,' '
CT_SET:     STA     TIME_STR+2

            ; MM
            LDA     TIMBUF+4
            CALL    BCD2ASC
            MOV     A,H
            STA     TIME_STR+3
            MOV     A,L
            STA     TIME_STR+4

            ; second colon matches first
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

; ============================================================
; Build "20YY-MM-DD"
; ============================================================
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

; ============================================================
; Helpers
; ============================================================
TOGGLE_BLINK:
            LDA     BLINK
            XRI     01H
            STA     BLINK
            RET

; Toggle only bit0 on the SC719 port (E=0, RS=0, data=0 -> safe)
TOGGLE_LED0:
            LDA     LED0
            XRI     01H
            STA     LED0
            ANI     01H
            OUT     PORT_LCD
            RET

; BCD in A -> ASCII digits (H tens, L ones)
BCD2ASC:
            MOV     D,A
            ANI     00FH
            ADI     '0'
            MOV     L,A
            MOV     A,D
            ANI     0F0H
            RRC
            RRC
            RRC
            RRC
            ADI     '0'
            MOV     H,A
            RET

; Print B bytes from [HL]
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

; ============================================================
; LCD 4-bit driver (SC719 mapping)
;   bit2=RS, bit3=E, bits4-7=D4-D7, R/W low
; ============================================================
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
            ANI     0F0H           ; RS=0
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

            ; 8-bit wake (send 0x3 high nibble three times)
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS
            MVI     A,030H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; switch to 4-bit
            MVI     A,020H
            CALL    LCD_NIB_CMD
            CALL    DELAY_10MS

            ; function set / display / entry
            MVI     A,028H
            CALL    LCD_BYTE_CMD
            MVI     A,008H
            CALL    LCD_BYTE_CMD
            MVI     A,001H
            CALL    LCD_BYTE_CMD
            CALL    DELAY_60MS
            MVI     A,006H
            CALL    LCD_BYTE_CMD
            MVI     A,00CH
            CALL    LCD_BYTE_CMD
            RET

; ============================================================
; Delays (crude)
; ============================================================
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

SHORTDLY:
            LXI     H,2000H
SD1:        DCX     H
            MOV     A,H
            ORA     L
            JNZ     SD1
            RET

; ============================================================
; Data + Safe stack
; ============================================================
TIMBUF:      DS      6
TIME_STR:    DS      8
DATE_STR:    DS      10
PREV_SEC:    DB      00H
BLINK:       DB      00H
LED0:        DB      00H

STACK:       DS      80
STACKEND:

            END     START
