; romwbw.asm
; Small RomWBW HBIOS helper library for Z80/Z180 CP/M programs.
;
; This is intentionally tiny.  It gives demo programs one shared place for
; common HBIOS constants and the RTC call used by the SC727/DSRTC clock.
;
; RTC convention used by the existing KD5VMF LCD CLOCK style programs:
;   HL -> six-byte buffer
;   call HbiosRtcGetTime
;   buffer receives BCD bytes: YY MM DD HH MM SS
;
; Typical include order:
;   include "romwbw.asm"
;   include "utility.asm"

IFNDEF ROMWBW_ASM
ROMWBW_ASM: equ 1

HBIOS_INVOKE:       equ 0fff0h
HBIOS_RTC_GETTIME:  equ 020h

; HL = pointer to six-byte RTC buffer: YY MM DD HH MM SS.
HbiosRtcGetTime:
        ld      b,HBIOS_RTC_GETTIME
        call    HBIOS_INVOKE
        ret

; A = packed BCD, returns binary 0..99 in A.
BcdToBinA:
        ld      b,a
        and     0fh
        ld      c,a                     ; ones
        ld      a,b
        and     0f0h
        rrca
        rrca
        rrca
        rrca                            ; tens
        ld      b,a
        add     a,a                     ; 2*tens
        add     a,a                     ; 4*tens
        add     a,b                     ; 5*tens
        add     a,a                     ; 10*tens
        add     a,c
        ret

; A = packed BCD, returns D=tens ASCII, E=ones ASCII.
BcdToAscii2:
        ld      b,a
        and     0f0h
        rrca
        rrca
        rrca
        rrca
        add     a,'0'
        ld      d,a
        ld      a,b
        and     0fh
        add     a,'0'
        ld      e,a
        ret

; A = 0..15 nibble, returns ASCII hex character in A.
HexNibbleA:
        and     0fh
        cp      10
        jp      c,HexNibbleDigit
        add     a,'A'-10
        ret
HexNibbleDigit:
        add     a,'0'
        ret

ENDIF
