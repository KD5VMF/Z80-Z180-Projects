; sc700.asm
; KD5VMF / ChatGPT helper library for SC700 Z180 + SC719 digital I/O cards.
;
; Purpose:
;   Small, safe helpers for demos that use three SC719 8-bit I/O cards at
;   ports 00h, 01h, and 02h.  These are intended for LED/front-panel style
;   output and simple input sampling.
;
; Default ports for the user's SC700 setup:
;   SC719_PORT0 = 00h
;   SC719_PORT1 = 01h
;   SC719_PORT2 = 02h
;
; Safety:
;   The SC719 output headers are real outputs.  If external hardware is wired
;   to the cards, review the program first.  A program can set
;   SC719_WRITE_ENABLE equ 0 before including this file to make write helpers
;   return without changing the outputs.
;
; Usage:
;   include "sc700.asm"
;   call Sc719ReadPorts        ; Sc719In0/In1/In2 updated
;   ld   a,0ffh
;   ld   b,055h
;   ld   c,0aah
;   call Sc719WriteABC         ; port0=A, port1=B, port2=C
;   call Sc719AllOff

IFNDEF SC700_ASM
SC700_ASM: equ 1

IFNDEF SC719_PORT0
SC719_PORT0: equ 00h
ENDIF
IFNDEF SC719_PORT1
SC719_PORT1: equ 01h
ENDIF
IFNDEF SC719_PORT2
SC719_PORT2: equ 02h
ENDIF
IFNDEF SC719_WRITE_ENABLE
SC719_WRITE_ENABLE: equ 1
ENDIF

; ------------------------------------------------------------
; Read all three SC719 input ports into RAM shadows.

Sc719ReadPorts:
        in      a,(SC719_PORT0)
        ld      (Sc719In0),a
        in      a,(SC719_PORT1)
        ld      (Sc719In1),a
        in      a,(SC719_PORT2)
        ld      (Sc719In2),a
        ret

; ------------------------------------------------------------
; Write A/B/C to SC719 port0/port1/port2.
; A is not preserved.

Sc719WriteABC:
        IF SC719_WRITE_ENABLE
        out     (SC719_PORT0),a
        ld      a,b
        out     (SC719_PORT1),a
        ld      a,c
        out     (SC719_PORT2),a
        ENDIF
        ret

; Write A to port0 only.
Sc719Write0:
        IF SC719_WRITE_ENABLE
        out     (SC719_PORT0),a
        ENDIF
        ret

; Write A to port1 only.
Sc719Write1:
        IF SC719_WRITE_ENABLE
        out     (SC719_PORT1),a
        ENDIF
        ret

; Write A to port2 only.
Sc719Write2:
        IF SC719_WRITE_ENABLE
        out     (SC719_PORT2),a
        ENDIF
        ret

; Turn all three SC719 output bytes off.
Sc719AllOff:
        xor     a
        ld      b,a
        ld      c,a
        jp      Sc719WriteABC

; ------------------------------------------------------------
; A = 0..8, returns an LED bar mask in A.
; 0 -> 00h, 1 -> 01h, ... 8 -> FFh.

Sc719Bar8:
        and     0fh
        cp      9
        jp      c,Sc719BarOk
        ld      a,8
Sc719BarOk:
        ld      e,a
        ld      d,0
        ld      hl,Sc719BarTable
        add     hl,de
        ld      a,(hl)
        ret

; A = 0..255, returns a rough 8-LED bar in A.
Sc719ByteToBar:
        rrca
        rrca
        rrca
        rrca
        and     0fh
        srl     a                       ; 0..7
        inc     a                       ; 1..8 for nonzero-ish display
        jp      Sc719Bar8

Sc719BarTable:
        defb    00h,01h,03h,07h,0fh,1fh,3fh,7fh,0ffh

; RAM shadows for input readings.
Sc719In0:       defb 0
Sc719In1:       defb 0
Sc719In2:       defb 0

ENDIF
