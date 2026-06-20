; lcd1602_sc719.asm
; HD44780/LCD1602 4-bit driver through one SC719 output byte.
;
; This matches the KD5VMF LCD CLOCK wiring:
;   SC719 bit2 -> LCD RS
;   SC719 bit3 -> LCD E
;   SC719 bit4 -> LCD D4
;   SC719 bit5 -> LCD D5
;   SC719 bit6 -> LCD D6
;   SC719 bit7 -> LCD D7
;   LCD RW     -> GND
;
; Default LCD_PORT is 00h.  Override by defining LCD_PORT before include.
; This library owns that port while the LCD is connected.
;
; Useful calls:
;   call LCDInit
;   call LCDClear
;   call LCDSetLine1 / LCDSetLine2
;   ld hl,Message0
;   call LCDPrintZ          ; zero-terminated string
;   ld a,55h
;   call LCDWriteHex8

IFNDEF LCD1602_SC719_ASM
LCD1602_SC719_ASM: equ 1

IFNDEF LCD_PORT
LCD_PORT:       equ 00h
ENDIF

LCD_RS:         equ 00000100b
LCD_E:          equ 00001000b

LCDInit:
        xor     a
        ld      (LCDCtl),a
        ld      (LCDShadow),a
        out     (LCD_PORT),a
        call    LCDDelayLong
        call    LCDDelayLong
        call    LCDDelayLong

        ld      a,030h
        call    LCDPulseRaw
        call    LCDDelayLong
        ld      a,030h
        call    LCDPulseRaw
        call    LCDDelayLong
        ld      a,030h
        call    LCDPulseRaw
        call    LCDDelayCmd
        ld      a,020h                  ; switch to 4-bit mode
        call    LCDPulseRaw
        call    LCDDelayCmd

        ld      a,028h                  ; 4-bit, 2 line, 5x8
        call    LCDCommand
        ld      a,00ch                  ; display on, cursor off
        call    LCDCommand
        ld      a,006h                  ; entry mode
        call    LCDCommand
        jp      LCDClear

LCDClear:
        ld      a,001h
        call    LCDCommand
        jp      LCDDelayLong

LCDHome:
        ld      a,002h
        call    LCDCommand
        jp      LCDDelayLong

LCDSetLine1:
        ld      a,080h
        jp      LCDCommand

LCDSetLine2:
        ld      a,0c0h
        jp      LCDCommand

; HL points to zero-terminated string.
LCDPrintZ:
        ld      a,(hl)
        or      a
        ret     z
        inc     hl
        call    LCDData
        jp      LCDPrintZ

; Output A as two hex digits.
LCDWriteHex8:
        push    af
        rrca
        rrca
        rrca
        rrca
        call    LCDHexNibble
        call    LCDData
        pop     af
        call    LCDHexNibble
        jp      LCDData

LCDHexNibble:
        and     0fh
        cp      10
        jp      c,LCDHexDigit
        add     a,'A'-10
        ret
LCDHexDigit:
        add     a,'0'
        ret

LCDCommand:
        ld      (LCDByte),a
        xor     a
        ld      (LCDCtl),a
        ld      a,(LCDByte)
        call    LCDSendByte
        jp      LCDDelayCmd

LCDData:
        ld      (LCDByte),a
        ld      a,LCD_RS
        ld      (LCDCtl),a
        ld      a,(LCDByte)
        call    LCDSendByte
        jp      LCDDelayTiny

LCDSendByte:
        ld      b,a
        and     0f0h
        ld      c,a
        ld      a,(LCDCtl)
        or      c
        call    LCDPulseByte

        ld      a,b
        add     a,a
        add     a,a
        add     a,a
        add     a,a
        and     0f0h
        ld      c,a
        ld      a,(LCDCtl)
        or      c
        jp      LCDPulseByte

; A already has the desired LCD nibble in bits 4..7.
LCDPulseRaw:
        jp      LCDPulseByte

LCDPulseByte:
        ld      (LCDShadow),a
        out     (LCD_PORT),a
        or      LCD_E
        out     (LCD_PORT),a
        call    LCDDelayTiny
        ld      a,(LCDShadow)
        out     (LCD_PORT),a
        jp      LCDDelayTiny

LCDDelayTiny:
        ld      b,80
LCDDelayTinyLoop:
        djnz    LCDDelayTinyLoop
        ret

LCDDelayCmd:
        ld      bc,900
LCDDelayCmdLoop:
        dec     bc
        ld      a,b
        or      c
        jp      nz,LCDDelayCmdLoop
        ret

LCDDelayLong:
        ld      bc,6500
LCDDelayLongLoop:
        dec     bc
        ld      a,b
        or      c
        jp      nz,LCDDelayLongLoop
        ret

LCDByte:        defb 0
LCDCtl:         defb 0
LCDShadow:      defb 0

ENDIF
