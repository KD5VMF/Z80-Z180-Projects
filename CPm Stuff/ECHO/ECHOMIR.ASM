; =====================================================================
; ECHOMIR.ASM — SC719 "mirror" echo (8080 strict, CP/M .COM)
; Copies every bit seen on the SC719 input pins back to its outputs.
; There is NO protocol: whatever comes in immediately goes out.
; ---------------------------------------------------------------------
; Build on CP/M:
;   A>ASM ECHOMIR
;   A>LOAD ECHOMIR
;   A>ECHOMIR
; To stop: warm boot (no BDOS calls in the hot loop).
; =====================================================================

            ORG     0100H

; -------- configuration (edit these for your wiring) --------
DIO_PORT    EQU     030H        ; SC719 base I/O port (0x30 / decimal 48)

; OPTIONAL polarity fixes:
; If your inputs read inverted, set IN_INV  = 0FFH
; If your outputs drive inverted (active-low LEDs), set OUT_INV = 0FFH
IN_INV      EQU     000H
OUT_INV     EQU     000H

; -------- code --------
START:
            ; Initialize outputs to current inputs (so we start "mirrored")
            IN      DIO_PORT
            XRI     IN_INV
            XRI     OUT_INV
            OUT     DIO_PORT

; Tight mirror loop: OUT <= (IN ^ IN_INV) ^ OUT_INV
LOOP:
            IN      DIO_PORT        ; read physical pins
            XRI     IN_INV          ; optional input inversion
            XRI     OUT_INV         ; optional output inversion
            OUT     DIO_PORT        ; drive pins exactly as (possibly fixed) input
            JMP     LOOP

            END     START
