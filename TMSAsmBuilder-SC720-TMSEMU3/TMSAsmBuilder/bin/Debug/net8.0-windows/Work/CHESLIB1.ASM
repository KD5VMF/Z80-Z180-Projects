; CHESLIB1.ASM
; Simple J.B. Langston TMS9918A-library test for CP/M .COM.
; Build on Windows with sjasmplus, then send CHESLIB1.HEX by PIP/LOAD or CHESLIB1.COM by XM.

        org 100h

        ld      (OldSP),sp
        ld      sp,Stack

        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait
        call    TmsProbe
        jp      z,NoTms

        ld      hl,TmsFont
        call    TmsTextMode
        ld      a,TmsDarkBlue
        call    TmsBackground
        ld      a,TmsWhite
        call    TmsTextColor

        call    DrawScreen
Hold:
        jp      Hold

DrawScreen:
        ld      a,9
        ld      e,1
        call    TmsTextPos
        ld      hl,Title
        call    TmsStrOut

        ld      a,14
        ld      e,4
        call    TmsTextPos
        ld      hl,Row8
        call    TmsStrOut
        ld      a,14
        ld      e,5
        call    TmsTextPos
        ld      hl,Row7
        call    TmsStrOut
        ld      a,14
        ld      e,6
        call    TmsTextPos
        ld      hl,Row6
        call    TmsStrOut
        ld      a,14
        ld      e,7
        call    TmsTextPos
        ld      hl,Row5
        call    TmsStrOut
        ld      a,14
        ld      e,8
        call    TmsTextPos
        ld      hl,Row4
        call    TmsStrOut
        ld      a,14
        ld      e,9
        call    TmsTextPos
        ld      hl,Row3
        call    TmsStrOut
        ld      a,14
        ld      e,10
        call    TmsTextPos
        ld      hl,Row2
        call    TmsStrOut
        ld      a,14
        ld      e,11
        call    TmsTextPos
        ld      hl,Row1
        call    TmsStrOut

        ld      a,11
        ld      e,13
        call    TmsTextPos
        ld      hl,Files
        call    TmsStrOut

        ld      a,7
        ld      e,18
        call    TmsTextPos
        ld      hl,Note
        call    TmsStrOut
        ret

NoTmsMessage:
        defb    "TMS9918A not found, aborting!$"
NoTms:
        ld      de,NoTmsMessage
        call    strout
        ld      sp,(OldSP)
        rst     0

TmsFont:
        include "TmsFont.asm"
        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

Title:  defb    "SC720 TMSEMU3 CHESS TEST",0
Row8:   defb    "8  r n b q k b n r",0
Row7:   defb    "7  p p p p p p p p",0
Row6:   defb    "6  . . . . . . . .",0
Row5:   defb    "5  . . . . . . . .",0
Row4:   defb    "4  . . . . . . . .",0
Row3:   defb    "3  . . . . . . . .",0
Row2:   defb    "2  P P P P P P P P",0
Row1:   defb    "1  R N B Q K B N R",0
Files:  defb    "   a b c d e f g h",0
Note:   defb    "Library build OK. Next: animate pieces.",0

OldSP:  defw    0
        defs    128
Stack:
