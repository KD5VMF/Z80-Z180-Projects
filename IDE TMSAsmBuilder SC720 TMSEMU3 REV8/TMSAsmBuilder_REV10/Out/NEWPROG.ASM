; NEWPROG.ASM
; Blank REV10 sjasmplus / CP/M .COM template.
;
; Build output now creates a fresh folder under Builds containing:
;   NEWPROG.ASM
;   NEWPROG.HEX
;   NEWPROG.COM
;
; Common includes:
;   include "tms.asm"
;   include "z180.asm"
;   include "utility.asm"
;
; SC700 extras, if wanted:
;   include "romwbw.asm"
;   include "sc700.asm"
;   include "math8.asm"

        org 100h

Start:
        ; your code here
        rst     0
