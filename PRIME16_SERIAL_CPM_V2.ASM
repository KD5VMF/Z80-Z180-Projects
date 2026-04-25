        ORG     0100H

BDOS    EQU     0005H
CONIN   EQU     01H
CONOUT  EQU     02H
CONST   EQU     0BH

START   LXI     SP,STKTOP
        LXI     H,0002H
        SHLD    NVAL

MAINLP  CALL    ABORT
        CALL    ISPRM
        JNC     NEXTN
        LHLD    NVAL
        CALL    PDEC
        CALL    CRLF

NEXTN   LHLD    NVAL
        INX     H
        SHLD    NVAL
        MOV     A,H
        ORA     L
        JNZ     MAINLP
        RET

ABORT   MVI     C,CONST
        CALL    BDOS
        ORA     A
        RZ
        MVI     C,CONIN
        CALL    BDOS
        CPI     03H
        RNZ
        RET

ISPRM   LHLD    NVAL
        MOV     A,H
        ORA     A
        JNZ     BIGCHK
        MOV     A,L
        CPI     02H
        JC      NOTPR
        JZ      YESPR

BIGCHK  MOV     A,L
        ANI     01H
        JZ      NOTPR
        LXI     H,0003H
        SHLD    DVAL

DIVLP   LHLD    DVAL
        XCHG
        LHLD    NVAL
        CALL    CMPHD
        JNC     YESPR
        CALL    DIVTST
        ORA     A
        JZ      NOTPR
        LHLD    DVAL
        INX     H
        INX     H
        SHLD    DVAL
        JMP     DIVLP

YESPR   STC
        RET

NOTPR   ORA     A
        RET

; CMPHD COMPARES HL WITH DE
; CARRY SET IF HL < DE
CMPHD   MOV     A,H
        CMP     D
        JC      CMPLO
        JNZ     CMPHI
        MOV     A,L
        CMP     E
        JC      CMPLO
CMPHI   ORA     A
        RET
CMPLO   STC
        RET

; DIVTST RETURNS A=0 IF NVAL DIVISIBLE BY DVAL, A=1 IF NOT
DIVTST  LHLD    NVAL
        SHLD    REMDR

DTSUB   LHLD    REMDR
        XCHG
        LHLD    DVAL
        XCHG
        LHLD    REMDR
        CALL    CMPHD
        JC      DTEND
        LHLD    REMDR
        XCHG
        LHLD    DVAL
        MOV     A,E
        SUB     L
        MOV     E,A
        MOV     A,D
        SBB     H
        MOV     D,A
        XCHG
        SHLD    REMDR
        JMP     DTSUB

DTEND   LHLD    REMDR
        MOV     A,H
        ORA     L
        JZ      DTYES
        MVI     A,01H
        RET
DTYES   XRA     A
        RET

; PRINT HL AS UNSIGNED DECIMAL, NO LEADING ZEROES
PDEC    SHLD    PVAL
        MVI     B,00H
        LXI     D,10000
        CALL    DIGIT
        LXI     D,1000
        CALL    DIGIT
        LXI     D,100
        CALL    DIGIT
        LXI     D,10
        CALL    DIGIT
        LHLD    PVAL
        MOV     A,L
        ADI     '0'
        CALL    PUTCH
        RET

DIGIT   MVI     C,'0'
DGLOP   LHLD    PVAL
        CALL    CMPHD
        JC      DGOUT
        LHLD    PVAL
        MOV     A,L
        SUB     E
        MOV     L,A
        MOV     A,H
        SBB     D
        MOV     H,A
        SHLD    PVAL
        INR     C
        JMP     DGLOP

DGOUT   MOV     A,C
        CPI     '0'
        JNZ     DGPRT
        MOV     A,B
        ORA     A
        RZ
        MOV     A,C
DGPRT   MVI     B,01H
        CALL    PUTCH
        RET

CRLF    MVI     A,0DH
        CALL    PUTCH
        MVI     A,0AH
        CALL    PUTCH
        RET

PUTCH   PUSH    B
        PUSH    D
        PUSH    H
        MOV     E,A
        MVI     C,CONOUT
        CALL    BDOS
        POP     H
        POP     D
        POP     B
        RET

NVAL    DW      0000H
DVAL    DW      0000H
REMDR   DW      0000H
PVAL    DW      0000H
        DS      64
STKTOP  EQU     $
        END     START
