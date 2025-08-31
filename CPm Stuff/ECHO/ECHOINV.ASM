; =====================================================================
; ECHOINV.ASM — SC719 "invert mirror" echo (8080 strict, CP/M .COM)
; Reads SC719 pins, optionally normalizes polarity, then INVERTS the
; received value and outputs it immediately. No protocol, no delays.
; ---------------------------------------------------------------------
; Build (on CP/M):
;   A>ASM ECHOINV
;   A>LOAD ECHOINV
;   A>ECHOINV
; Stop with a warm boot (no BDOS calls in hot loop).
; =====================================================================

            ORG     0100H

; -------- configuration (edit for your wiring) --------
DIO_PORT    EQU     030H        ; SC719 base I/O port (0x30 / decimal 48)

; If your inputs read inverted, set IN_INV  = 0FFH
; If your outputs must be driven active-low, set OUT_INV = 0FFH
IN_INV      EQU     000H
OUT_INV     EQU     000H

; What to invert from the received value **before** output:
;   0FFH = invert ALL 8 bits (D0..D7)
;   07FH = invert ONLY D0..D6 (leave D7 as-is)
INV_MASK    EQU     0FFH

; -------- code --------
START:
            ; Initialize outputs to inverted current inputs
            IN      DIO_PORT
            XRI     IN_INV      ; fix incoming polarity (if needed)
            XRI     INV_MASK    ; invert selected bits
            XRI     OUT_INV     ; fix outgoing polarity (if needed)
            OUT     DIO_PORT

; Tight loop: OUT <= ((IN ^ IN_INV) ^ INV_MASK) ^ OUT_INV
LOOP:
            IN      DIO_PORT        ; read physical pins
            XRI     IN_INV          ; normalize input (optional)
            XRI     INV_MASK        ; *** invert received bits ***
            XRI     OUT_INV         ; normalize output (optional)
            OUT     DIO_PORT        ; drive pins
            JMP     LOOP

            END     START
