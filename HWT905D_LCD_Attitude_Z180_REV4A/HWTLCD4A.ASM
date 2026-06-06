;===============================================================================
; HWTLCD4A.ASM
;
; KD5VMF Z180 / SC719 LCD1602 + HWT905D Attitude Display
; REV4A - PITCH/ROLL FIX + TOP LINE MOVED RIGHT ONE
;
; Normal display:
;      HDG 123 NE
;    P+005 R-002 OK
;
; Controls:
;   Q = exit to CP/M
;   0-7 = select HBIOS serial unit and re-init it to 9600
;
;===============================================================================

        ORG     0100H

        JMP     START

BDOS    EQU     0005H
PORTLD  EQU     000H

LCDEVR  EQU     002H

; RomWBW serial line config:
; 9600 baud, 8 data, no parity, 1 stop
SER960  EQU     0703H

START   LXI     SP,STACKE

        XRA     A
        STA     PSTATE
        STA     PINDEX
        STA     PSUM
        STA     NEWFLG
        STA     RAWFLG
        STA     DISPC
        STA     LOST

        MVI     A,001H
        STA     SELUNI

        XRA     A
        STA     BYCNT
        STA     BYCNT+1
        STA     PKTCNT
        STA     PKTCNT+1
        STA     LASTB
        STA     LAST0
        STA     LAST1
        STA     LAST2
        STA     LAST3

        MVI     A,0C8H
        STA     AGE

        CALL    DLY60
        CALL    LINI
        CALL    LCLR

        CALL    INIHBI
        CALL    FLUSH
        CALL    SHNOB

MAIN    CALL    PSER
        CALL    CHKEY

        LDA     NEWFLG
        ORA     A
        JZ      CKRAW

        XRA     A
        STA     NEWFLG

        CALL    BLDLN
        CALL    WRTLN
        JMP     MAIN

CKRAW   LDA     RAWFLG
        ORA     A
        JZ      CKAGE

        XRA     A
        STA     RAWFLG

        LHLD    PKTCNT
        MOV     A,H
        ORA     L
        JNZ     CKAGE

        CALL    SHRAW
        JMP     MAIN

CKAGE   LDA     AGE
        ORA     A
        JZ      TOUT

        DCR     A
        STA     AGE
        CALL    SDLY
        JMP     MAIN

TOUT    LDA     LOST
        ORA     A
        JNZ     TOUT2

        LHLD    BYCNT
        MOV     A,H
        ORA     L
        JZ      TNO

        CALL    SHRAW
        JMP     TSET

TNO     CALL    SHNOB

TSET    MVI     A,001H
        STA     LOST

TOUT2   CALL    SDLY
        JMP     MAIN

CHKEY   MVI     C,006H
        MVI     E,0FFH
        CALL    BDOS
        ORA     A
        RZ

        CPI     051H
        JZ      EXIT
        CPI     071H
        JZ      EXIT

        CPI     030H
        JC      NOKEY
        CPI     038H
        JNC     NOKEY

        SUI     030H
        STA     SELUNI

        CALL    RSETC
        CALL    INIHBI
        CALL    FLUSH
        CALL    SHNOB
        RET

NOKEY   RET

EXIT    CALL    SHEX
        CALL    DLY60
        JMP     0000H

RSETC   XRA     A
        STA     BYCNT
        STA     BYCNT+1
        STA     PKTCNT
        STA     PKTCNT+1
        STA     LASTB
        STA     LAST0
        STA     LAST1
        STA     LAST2
        STA     LAST3
        STA     PSTATE
        STA     PINDEX
        STA     PSUM
        STA     NEWFLG
        STA     RAWFLG
        STA     LOST
        MVI     A,0C8H
        STA     AGE
        RET

;===============================================================================
; RomWBW HBIOS serial calls
;===============================================================================

HBCL    DB      0CFH
        RET

HBIST   LDA     SELUNI
        MOV     C,A
        MVI     B,002H
        CALL    HBCL
        MOV     A,E
        RET

HBIN    LDA     SELUNI
        MOV     C,A
        MVI     B,000H
        CALL    HBCL
        MOV     A,E
        RET

INIHBI  LDA     SELUNI
        MOV     C,A
        MVI     B,004H
        LXI     D,SER960
        MVI     L,000H
        CALL    HBCL
        RET

FLUSH   MVI     A,0FFH
        STA     PLCNT

FLUS1   CALL    HBIST
        ORA     A
        JZ      FLUSD

        CALL    HBIN

        LDA     PLCNT
        DCR     A
        STA     PLCNT
        JNZ     FLUS1

FLUSD   RET

;===============================================================================
; Poll selected HBIOS serial unit
;===============================================================================

PSER    MVI     A,040H
        STA     PLCNT

POLL1   CALL    HBIST
        ORA     A
        JZ      PDONE

        CALL    HBIN
        STA     LASTB
        CALL    SAVBYT

        CALL    INCBYT
        MVI     A,001H
        STA     RAWFLG

        LDA     LASTB
        CALL    PBYTE

        LDA     PLCNT
        DCR     A
        STA     PLCNT
        JNZ     POLL1

PDONE   RET

SAVBYT  LDA     LAST1
        STA     LAST0
        LDA     LAST2
        STA     LAST1
        LDA     LAST3
        STA     LAST2
        LDA     LASTB
        STA     LAST3
        RET

INCBYT  LHLD    BYCNT
        INX     H
        SHLD    BYCNT
        RET

INCPKT  LHLD    PKTCNT
        INX     H
        SHLD    PKTCNT
        RET

;===============================================================================
; HWT905D parser
;===============================================================================

PBYTE   STA     INBYTE

        LDA     PSTATE
        ORA     A
        JZ      PBWAIT

        CPI     001H
        JZ      PBTYPE

        JMP     PBDAT

PBWAIT  LDA     INBYTE
        CPI     055H
        RNZ

        STA     FRAME
        STA     PSUM

        MVI     A,001H
        STA     PSTATE
        STA     PINDEX
        RET

PBTYPE  LDA     INBYTE
        STA     FRAME+1

        MOV     B,A
        LDA     PSUM
        ADD     B
        STA     PSUM

        MVI     A,002H
        STA     PSTATE
        STA     PINDEX
        RET

PBDAT   LDA     PINDEX
        MOV     E,A
        MVI     D,000H
        LXI     H,FRAME
        DAD     D

        LDA     INBYTE
        MOV     M,A

        LDA     PINDEX
        CPI     00AH
        JZ      PBCHK

        LDA     PSUM
        MOV     B,A
        LDA     INBYTE
        ADD     B
        STA     PSUM

        LDA     PINDEX
        INR     A
        STA     PINDEX
        RET

PBCHK   LDA     PSUM
        MOV     B,A
        LDA     INBYTE
        CMP     B
        JNZ     PBAD

        LDA     FRAME+1
        CPI     053H
        JNZ     PBDON

        CALL    PARSE
        CALL    INCPKT

PBDON   XRA     A
        STA     PSTATE
        RET

PBAD    XRA     A
        STA     PSTATE
        RET

;===============================================================================
; Parse angle packet
; Field 1 displayed as PITCH.
; Field 2 displayed as ROLL.
;===============================================================================

PARSE   LDA     FRAME+2
        MOV     L,A
        LDA     FRAME+3
        MOV     H,A
        CALL    RAWDG
        STA     PDEG
        LDA     SIGNC
        STA     PSIGN

        LDA     FRAME+4
        MOV     L,A
        LDA     FRAME+5
        MOV     H,A
        CALL    RAWDG
        STA     RDEG
        LDA     SIGNC
        STA     RSIGN

        LDA     FRAME+6
        MOV     L,A
        LDA     FRAME+7
        MOV     H,A
        CALL    RAWDG
        STA     YDEG

        LDA     SIGNC
        CPI     02DH
        JZ      YNEG

        LDA     YDEG
        MOV     L,A
        MVI     H,000H
        SHLD    HDEG
        JMP     PGOT

YNEG    LDA     YDEG
        ORA     A
        JZ      YZERO

        MOV     E,A
        MVI     D,000H
        LXI     H,0168H
        CALL    SUBDE
        SHLD    HDEG
        JMP     PGOT

YZERO   LXI     H,0000H
        SHLD    HDEG

PGOT    MVI     A,0FFH
        STA     AGE

        XRA     A
        STA     LOST

        LDA     DISPC
        INR     A
        CPI     LCDEVR
        JC      PDSAV

        XRA     A
        STA     DISPC

        MVI     A,001H
        STA     NEWFLG
        RET

PDSAV   STA     DISPC
        RET

RAWDG   MOV     A,H
        ANI     080H
        JZ      RDPOS

        MVI     A,02DH
        STA     SIGNC

        MOV     A,L
        CMA
        MOV     L,A
        MOV     A,H
        CMA
        MOV     H,A
        INX     H
        JMP     RDGO

RDPOS   MVI     A,02BH
        STA     SIGNC

RDGO    CALL    DIV182
        RET

DIV182  MVI     D,000H

D182A   LXI     B,00B6H
        CALL    CMPBC
        JC      D182D

        CALL    SUBBC
        INR     D
        JMP     D182A

D182D   MOV     A,D
        RET

;===============================================================================
; Build attitude LCD lines
;===============================================================================

BLDLN   LXI     H,TPL1
        LXI     D,LINE1
        CALL    CPY16

        LXI     H,TPL2
        LXI     D,LINE2
        CALL    CPY16

; Heading digits at LINE1+7 because top row moved right one.
        LXI     H,LINE1+7
        SHLD    OUTPTR
        LHLD    HDEG
        CALL    PUT3

; Direction at LINE1+11 and LINE1+12.
        LHLD    HDEG
        CALL    GETDIR

        MOV     A,D
        STA     LINE1+11
        MOV     A,E
        STA     LINE1+12

        LDA     PSIGN
        STA     LINE2+2

        LXI     H,LINE2+3
        SHLD    OUTPTR
        LDA     PDEG
        MOV     L,A
        MVI     H,000H
        CALL    PUT3

        LDA     RSIGN
        STA     LINE2+8

        LXI     H,LINE2+9
        SHLD    OUTPTR
        LDA     RDEG
        MOV     L,A
        MVI     H,000H
        CALL    PUT3

        RET

GETDIR  LXI     B,0017H
        CALL    CMPBC
        JC      DIRN

        LXI     B,0044H
        CALL    CMPBC
        JC      DIRNE

        LXI     B,0071H
        CALL    CMPBC
        JC      DIRE

        LXI     B,009EH
        CALL    CMPBC
        JC      DIRSE

        LXI     B,00CBH
        CALL    CMPBC
        JC      DIRS

        LXI     B,00F8H
        CALL    CMPBC
        JC      DIRSW

        LXI     B,0125H
        CALL    CMPBC
        JC      DIRW

        LXI     B,0152H
        CALL    CMPBC
        JC      DIRNW

        JMP     DIRN

DIRN    MVI     D,04EH
        MVI     E,020H
        RET

DIRNE   MVI     D,04EH
        MVI     E,045H
        RET

DIRE    MVI     D,045H
        MVI     E,020H
        RET

DIRSE   MVI     D,053H
        MVI     E,045H
        RET

DIRS    MVI     D,053H
        MVI     E,020H
        RET

DIRSW   MVI     D,053H
        MVI     E,057H
        RET

DIRW    MVI     D,057H
        MVI     E,020H
        RET

DIRNW   MVI     D,04EH
        MVI     E,057H
        RET

PUT3    MVI     D,000H

P3H     LXI     B,0064H
        CALL    CMPBC
        JC      P3HD
        CALL    SUBBC
        INR     D
        JMP     P3H

P3HD    MOV     A,D
        ADI     030H
        CALL    OPCHR

        MVI     D,000H

P3T     LXI     B,000AH
        CALL    CMPBC
        JC      P3TD
        CALL    SUBBC
        INR     D
        JMP     P3T

P3TD    MOV     A,D
        ADI     030H
        CALL    OPCHR

        MOV     A,L
        ADI     030H
        CALL    OPCHR
        RET

PUT4H   MOV     A,H
        CALL    PUT2H
        MOV     A,L
        CALL    PUT2H
        RET

PUT2H   PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        ANI     00FH
        CALL    HEXCH
        CALL    OPCHR
        POP     PSW
        ANI     00FH
        CALL    HEXCH
        CALL    OPCHR
        RET

HEXCH   CPI     00AH
        JC      HEXN
        ADI     037H
        RET

HEXN    ADI     030H
        RET

OPCHR   PUSH    H
        LHLD    OUTPTR
        MOV     M,A
        INX     H
        SHLD    OUTPTR
        POP     H
        RET

CPY16   MVI     B,010H

CP16A   MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     CP16A
        RET

CMPBC   MOV     A,H
        CMP     B
        RNZ
        MOV     A,L
        CMP     C
        RET

SUBBC   MOV     A,L
        SUB     C
        MOV     L,A
        MOV     A,H
        SBB     B
        MOV     H,A
        RET

SUBDE   MOV     A,L
        SUB     E
        MOV     L,A
        MOV     A,H
        SBB     D
        MOV     H,A
        RET

;===============================================================================
; LCD write screens
;===============================================================================

WRTLN   MVI     A,000H
        CALL    LSET
        LXI     H,LINE1
        MVI     B,010H
        CALL    LPUT

        MVI     A,040H
        CALL    LSET
        LXI     H,LINE2
        MVI     B,010H
        CALL    LPUT
        RET

SHNOB   LXI     H,MSGNB1
        LXI     D,LINE1
        CALL    CPY16

        LXI     H,MSGNB2
        LXI     D,LINE2
        CALL    CPY16

        LDA     SELUNI
        ADI     030H
        STA     LINE1+1

        CALL    WRTLN
        RET

SHRAW   LXI     H,MSGRA1
        LXI     D,LINE1
        CALL    CPY16

        LXI     H,MSGRA2
        LXI     D,LINE2
        CALL    CPY16

        LDA     SELUNI
        ADI     030H
        STA     LINE1+1

        LXI     H,LINE1+7
        SHLD    OUTPTR
        LHLD    BYCNT
        CALL    PUT4H

        LXI     H,LINE1+13
        SHLD    OUTPTR
        LDA     LASTB
        CALL    PUT2H

        LXI     H,LINE2+2
        SHLD    OUTPTR
        LDA     LAST0
        CALL    PUT2H

        LXI     H,LINE2+5
        SHLD    OUTPTR
        LDA     LAST1
        CALL    PUT2H

        LXI     H,LINE2+8
        SHLD    OUTPTR
        LDA     LAST2
        CALL    PUT2H

        LXI     H,LINE2+11
        SHLD    OUTPTR
        LDA     LAST3
        CALL    PUT2H

        CALL    WRTLN
        RET

SHEX    MVI     A,000H
        CALL    LSET
        LXI     H,MSGEX1
        MVI     B,010H
        CALL    LPUT

        MVI     A,040H
        CALL    LSET
        LXI     H,MSGEX2
        MVI     B,010H
        CALL    LPUT
        RET

;===============================================================================
; LCD routines
;===============================================================================

LPUT    MOV     A,B
        ORA     A
        RZ

LPUTA   MOV     A,M
        CALL    LDAT
        INX     H
        DCR     B
        JNZ     LPUTA
        RET

LPUL    OUT     PORTLD
        CALL    DTINY
        ORI     008H
        OUT     PORTLD
        CALL    DTINY
        ANI     0F7H
        OUT     PORTLD
        CALL    DTINY
        RET

LNC     ANI     0F0H
        CALL    LPUL
        RET

LND     ANI     0F0H
        ORI     004H
        CALL    LPUL
        RET

LCMD    PUSH    D
        MOV     D,A

        ANI     0F0H
        CALL    LNC

        MOV     A,D
        ANI     00FH
        RLC
        RLC
        RLC
        RLC
        ANI     0F0H
        CALL    LNC

        POP     D
        CALL    DLY2
        RET

LDAT    PUSH    D
        MOV     D,A

        ANI     0F0H
        CALL    LND

        MOV     A,D
        ANI     00FH
        RLC
        RLC
        RLC
        RLC
        ANI     0F0H
        CALL    LND

        POP     D
        CALL    DLY2
        RET

LSET    ORI     080H
        CALL    LCMD
        RET

LCLR    MVI     A,001H
        CALL    LCMD
        CALL    DLY60
        RET

LINI    XRA     A
        OUT     PORTLD
        CALL    DLY20

        MVI     A,030H
        CALL    LNC
        CALL    DLY10

        MVI     A,030H
        CALL    LNC
        CALL    DLY10

        MVI     A,030H
        CALL    LNC
        CALL    DLY10

        MVI     A,020H
        CALL    LNC
        CALL    DLY10

        MVI     A,028H
        CALL    LCMD

        MVI     A,008H
        CALL    LCMD

        MVI     A,001H
        CALL    LCMD
        CALL    DLY60

        MVI     A,006H
        CALL    LCMD

        MVI     A,00CH
        CALL    LCMD
        RET

;===============================================================================
; Delays
;===============================================================================

DTINY   PUSH    B
        MVI     B,012H

DTIN1   DCR     B
        JNZ     DTIN1
        POP     B
        RET

DLY2    PUSH    B
        PUSH    D
        MVI     B,008H

D2A     MVI     D,0FFH

D2B     DCR     D
        JNZ     D2B
        DCR     B
        JNZ     D2A

        POP     D
        POP     B
        RET

DLY10   PUSH    B
        MVI     B,005H

D10A    CALL    DLY2
        DCR     B
        JNZ     D10A

        POP     B
        RET

DLY20   PUSH    B
        MVI     B,00AH

D20A    CALL    DLY2
        DCR     B
        JNZ     D20A

        POP     B
        RET

DLY60   PUSH    B
        MVI     B,01EH

D60A    CALL    DLY2
        DCR     B
        JNZ     D60A

        POP     B
        RET

SDLY    LXI     H,1000H

SDLY1   DCX     H
        MOV     A,H
        ORA     L
        JNZ     SDLY1
        RET

;===============================================================================
; Data
;===============================================================================

; "   HDG 000 N   "
TPL1    DB      020H,020H,020H,048H,044H,047H,020H,030H
        DB      030H,030H,020H,04EH,020H,020H,020H,020H

; " P+000 R+000 OK "
TPL2    DB      020H,050H,02BH,030H,030H,030H,020H,052H
        DB      02BH,030H,030H,030H,020H,04FH,04BH,020H

; "U1 9600 NO BYTE "
MSGNB1  DB      055H,031H,020H,039H,036H,030H,030H,020H
        DB      04EH,04FH,020H,042H,059H,054H,045H,020H

; "Q EXIT 0-7 UNIT "
MSGNB2  DB      051H,020H,045H,058H,049H,054H,020H,030H
        DB      02DH,037H,020H,055H,04EH,049H,054H,020H

; "U1 RAW 0000 L00"
MSGRA1  DB      055H,031H,020H,052H,041H,057H,020H,030H
        DB      030H,030H,030H,020H,04CH,030H,030H,020H

; "T 00 00 00 00  "
MSGRA2  DB      054H,020H,030H,030H,020H,030H,030H,020H
        DB      030H,030H,020H,030H,030H,020H,020H,020H

; " EXIT TO CP/M   "
MSGEX1  DB      020H,045H,058H,049H,054H,020H,054H,04FH
        DB      020H,043H,050H,02FH,04DH,020H,020H,020H

; " SENSOR STOPPED "
MSGEX2  DB      020H,053H,045H,04EH,053H,04FH,052H,020H
        DB      053H,054H,04FH,050H,050H,045H,044H,020H

LINE1   DS      16
LINE2   DS      16

FRAME   DS      11

PSTATE  DB      00H
PINDEX  DB      00H
PSUM    DB      00H
INBYTE  DB      00H

NEWFLG  DB      00H
RAWFLG  DB      00H
DISPC   DB      00H
AGE     DB      00H
LOST    DB      00H
PLCNT   DB      00H

SELUNI  DB      01H
LASTB   DB      00H
LAST0   DB      00H
LAST1   DB      00H
LAST2   DB      00H
LAST3   DB      00H

BYCNT   DW      0000H
PKTCNT  DW      0000H

HDEG    DW      0000H
YDEG    DB      00H

PDEG    DB      00H
RDEG    DB      00H

PSIGN   DB      02BH
RSIGN   DB      02BH
SIGNC   DB      02BH

OUTPTR  DW      0000H

STACK   DS      128
STACKE

        END     START
