; HELLO.ASM
; TMS ASM Builder REV11 default CP/M Hello World.
;
; Build creates:
;   HELLO.COM
;   HELLO.HEX
;
; Transfer options:
;   XMODEM: C>XM R HELLO.COM
;   PIP/LOAD: C>PIP HELLO.HEX=CON:   then LOAD HELLO.HEX
;
; IMPORTANT for HEX paste in Tera Term:
;   use 1 ms per character and 1 ms per line.

        org     100h

Start:
        ld      de,HelloMsg
        call    strout
        rst     0

HelloMsg:
        db      13,10,'Hello from TMS ASM Builder REV11!',13,10,'$'

        include "utility.asm"
        end
