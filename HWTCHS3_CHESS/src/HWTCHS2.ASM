        ORG     0100H
BDOS    EQU     0005H
        JMP     START

START   XRA     A
        STA     GAMH
        STA     GAML
        CALL    INIT
MAIN    CALL    KEY
        CALL    DOMOV
        JMP     MAIN

INIT    CALL    INCGA
        LXI     H,INIBD
        LXI     D,BOARD
        MVI     B,64
INI1    MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     INI1
        LXI     H,MVTAB
        SHLD    MVPTR
        XRA     A
        STA     SIDE
        STA     MVL
        STA     MVH
        STA     LFR
        STA     LTO
        STA     LFG
        MVI     A,'.'
        STA     LPC
        STA     CAPC
        CALL    SCRN
        RET

INCGA   LDA     GAML
        INR     A
        STA     GAML
        RNZ
        LDA     GAMH
        INR     A
        STA     GAMH
        RET

SCRN    LXI     D,CLRS
        CALL    PSTR
        MVI     B,1
        MVI     C,8
        CALL    GOTO
        LXI     D,TTLMS
        CALL    PSTR
        MVI     B,2
        MVI     C,8
        CALL    GOTO
        LXI     D,SUBMS
        CALL    PSTR
        MVI     B,3
        MVI     C,8
        CALL    GOTO
        LXI     D,HLPMS
        CALL    PSTR
        CALL    FRAME
        CALL    DALL
        CALL    STAT
        RET

FRAME   MVI     B,5
        MVI     C,8
        CALL    GOTO
        LXI     D,COLMS
        CALL    PSTR
        MVI     D,0
FRM1    MOV     A,D
        ADD     A
        ADI     6
        MOV     B,A
        MVI     C,4
        CALL    GOTO
        LXI     H,BORDR
        CALL    PHSTR
        MOV     A,D
        ADD     A
        ADI     7
        MOV     B,A
        MVI     C,4
        CALL    GOTO
        MVI     E,' '
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        MVI     A,'8'
        SUB     D
        MOV     E,A
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        MVI     E,'|'
        CALL    PCH
        MVI     B,8
FRM2    MVI     E,' '
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        MVI     E,'|'
        CALL    PCH
        DCR     B
        JNZ     FRM2
        MVI     E,' '
        CALL    PCH
        MVI     A,'8'
        SUB     D
        MOV     E,A
        CALL    PCH
        INR     D
        MOV     A,D
        CPI     8
        JC      FRM1
        MVI     B,22
        MVI     C,4
        CALL    GOTO
        LXI     H,BORDR
        CALL    PHSTR
        MVI     B,23
        MVI     C,8
        CALL    GOTO
        LXI     D,COLMS
        CALL    PSTR
        RET

PHSTR   MOV     A,M
        CPI     0
        RZ
        MOV     E,A
        CALL    PCH
        INX     H
        JMP     PHSTR

DALL    XRA     A
        STA     IDX
DAL1    LDA     IDX
        CALL    DSQ
        LDA     IDX
        INR     A
        STA     IDX
        CPI     64
        JC      DAL1
        RET

DOMOV   LHLD    MVPTR
        MOV     A,M
        CPI     0FFH
        JZ      MVDN
        STA     LFR
        INX     H
        MOV     A,M
        STA     LTO
        INX     H
        MOV     A,M
        STA     LFG
        INX     H
        SHLD    MVPTR
        LDA     LFR
        CALL    BPTR
        MOV     A,M
        STA     LPC
        LDA     LTO
        CALL    BPTR
        MOV     A,M
        STA     CAPC
        CALL    THINK
        CALL    MARK
        LDA     LFR
        CALL    BPTR
        MVI     M,'.'
        LDA     LTO
        CALL    BPTR
        LDA     LPC
        MOV     M,A
        LDA     LFR
        CALL    DSQ
        LDA     LTO
        CALL    DSQ
        CALL    INCMV
        LDA     LFG
        ANI     01H
        JNZ     MOV1
        LDA     SIDE
        XRI     01H
        STA     SIDE
MOV1    CALL    STAT
        RET

MVDN    MVI     B,14
        MVI     C,48
        CALL    GOTO
        LXI     D,END1
        CALL    PSTR
        MVI     B,15
        MVI     C,48
        CALL    GOTO
        LXI     D,END2
        CALL    PSTR
        MVI     B,16
        MVI     C,48
        CALL    GOTO
        LXI     D,END3
        CALL    PSTR
        MVI     B,6
MVD1    CALL    PACE
        DCR     B
        JNZ     MVD1
        CALL    INIT
        RET

INCMV   LDA     MVL
        INR     A
        STA     MVL
        RNZ
        LDA     MVH
        INR     A
        STA     MVH
        RET

THINK   CALL    STAT
        MVI     B,14
        MVI     C,48
        CALL    GOTO
        LDA     SIDE
        ORA     A
        JZ      THW
        LXI     D,THBMS
        CALL    PSTR
        JMP     TH1
THW     LXI     D,THWMS
        CALL    PSTR
TH1     MVI     B,15
        MVI     C,48
        CALL    GOTO
        LXI     D,PLANM
        CALL    PSTR
        LDA     LPC
        MOV     E,A
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        LDA     LFR
        CALL    PSQ
        MVI     E,'-'
        CALL    PCH
        LDA     LTO
        CALL    PSQ
        LXI     D,PADMS
        CALL    PSTR
        MVI     B,16
        MVI     C,48
        CALL    GOTO
        LXI     D,SRCHM
        CALL    PSTR
        MVI     B,3
TH2     MVI     E,'.'
        CALL    PCH
        CALL    PACE
        DCR     B
        JNZ     TH2
        RET

MARK    LDA     LFR
        STA     SQI
        CALL    POS
        MVI     E,'*'
        CALL    PUTXY
        LDA     LTO
        STA     SQI
        CALL    POS
        MVI     E,'*'
        CALL    PUTXY
        CALL    PACE
        RET

DSQ     STA     SQI
        LDA     SQI
        CALL    BPTR
        MOV     A,M
        STA     TMP
        CALL    POS
        LDA     TMP
        MOV     E,A
        CALL    PUTXY
        RET

POS     LDA     SQI
        MOV     L,A
        MVI     H,0
        LXI     D,SROW
        DAD     D
        MOV     B,M
        LDA     SQI
        MOV     L,A
        MVI     H,0
        LXI     D,SCOL
        DAD     D
        MOV     C,M
        RET

BPTR    LXI     H,BOARD
        ORA     A
        RZ
        MOV     B,A
BPT1    INX     H
        DCR     B
        JNZ     BPT1
        RET

STAT    MVI     B,5
        MVI     C,48
        CALL    GOTO
        LXI     D,STGAM
        CALL    PSTR
        LDA     GAMH
        CALL    PHEX
        LDA     GAML
        CALL    PHEX
        LXI     D,PADMS
        CALL    PSTR
        MVI     B,6
        MVI     C,48
        CALL    GOTO
        LXI     D,STMOV
        CALL    PSTR
        LDA     MVH
        CALL    PHEX
        LDA     MVL
        CALL    PHEX
        LXI     D,PADMS
        CALL    PSTR
        MVI     B,7
        MVI     C,48
        CALL    GOTO
        LXI     D,STTRN
        CALL    PSTR
        LDA     SIDE
        ORA     A
        JZ      STW
        LXI     D,BLKMS
        CALL    PSTR
        JMP     ST2
STW     LXI     D,WHTMS
        CALL    PSTR
ST2     LXI     D,PADMS
        CALL    PSTR
        MVI     B,8
        MVI     C,48
        CALL    GOTO
        LXI     D,STLST
        CALL    PSTR
        LDA     LPC
        MOV     E,A
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        LDA     LFR
        CALL    PSQ
        MVI     E,'-'
        CALL    PCH
        LDA     LTO
        CALL    PSQ
        LXI     D,PADMS
        CALL    PSTR
        MVI     B,9
        MVI     C,48
        CALL    GOTO
        LXI     D,STCAP
        CALL    PSTR
        LDA     CAPC
        MOV     E,A
        CALL    PCH
        LXI     D,PADMS
        CALL    PSTR
        MVI     B,10
        MVI     C,48
        CALL    GOTO
        LXI     D,STSPD
        CALL    PSTR
        LDA     SPD
        ADI     '0'
        MOV     E,A
        CALL    PCH
        LXI     D,SPHLP
        CALL    PSTR
        MVI     B,12
        MVI     C,48
        CALL    GOTO
        LXI     D,STYLM
        CALL    PSTR
        RET

PSQ     PUSH    B
        PUSH    D
        MOV     C,A
        ANI     07H
        ADI     'A'
        MOV     E,A
        CALL    PCH
        MOV     A,C
        MVI     B,0
PSQ1    CPI     8
        JC      PSQ2
        SUI     8
        INR     B
        JMP     PSQ1
PSQ2    MVI     A,'8'
        SUB     B
        MOV     E,A
        CALL    PCH
        POP     D
        POP     B
        RET

KEY     MVI     C,6
        MVI     E,0FFH
        CALL    BDOS
        ORA     A
        RZ
        CPI     'Q'
        JZ      EXIT
        CPI     'q'
        JZ      EXIT
        CPI     '+'
        JZ      KFST
        CPI     '-'
        JZ      KSLW
        RET

KFST    LDA     SPD
        CPI     1
        RZ
        DCR     A
        STA     SPD
        CALL    STAT
        RET

KSLW    LDA     SPD
        CPI     9
        RZ
        INR     A
        STA     SPD
        CALL    STAT
        RET

EXIT    LXI     D,NORM
        CALL    PSTR
        JMP     0000H

PACE    PUSH    B
        PUSH    D
        PUSH    H
        LDA     SPD
        MOV     D,A
PAC1    CALL    KEY
        MVI     B,0
PAC2    MVI     C,0
PAC3    DCR     C
        JNZ     PAC3
        DCR     B
        JNZ     PAC2
        DCR     D
        JNZ     PAC1
        POP     H
        POP     D
        POP     B
        RET

PUTXY   MOV     A,E
        STA     TMP
        CALL    GOTO
        LDA     TMP
        MOV     E,A
        CALL    PCH
        RET

GOTO    PUSH    B
        PUSH    D
        MVI     E,27
        CALL    PCH
        MVI     E,'['
        CALL    PCH
        MOV     A,B
        CALL    P2D
        MVI     E,';'
        CALL    PCH
        MOV     A,C
        CALL    P2D
        MVI     E,'H'
        CALL    PCH
        POP     D
        POP     B
        RET

P2D     MVI     D,'0'
P2D1    CPI     10
        JC      P2D2
        SUI     10
        INR     D
        JMP     P2D1
P2D2    PUSH    PSW
        MOV     E,D
        CALL    PCH
        POP     PSW
        ADI     '0'
        MOV     E,A
        CALL    PCH
        RET

PHEX    PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        ANI     0FH
        CALL    PHN
        POP     PSW
        ANI     0FH
        CALL    PHN
        RET

PHN     CPI     10
        JC      PHN1
        ADI     7
PHN1    ADI     '0'
        MOV     E,A
        CALL    PCH
        RET

PSTR    PUSH    B
        PUSH    D
        PUSH    H
        MVI     C,9
        CALL    BDOS
        POP     H
        POP     D
        POP     B
        RET

PCH     PUSH    PSW
        PUSH    B
        PUSH    D
        PUSH    H
        MVI     C,2
        CALL    BDOS
        POP     H
        POP     D
        POP     B
        POP     PSW
        RET

CLRS    DB      27,'[2J',27,'[H',27,'[?25l',27,'[1;32;40m','$'
NORM    DB      27,'[0m',27,'[?25h',13,10,'$'
TTLMS   DB      'HWTCHS2  COMPUTER VS COMPUTER CHESS','$'
SUBMS   DB      'CP/M 8080 SAFE ANSI BOARD - NO FLASH REDRAW','$'
HLPMS   DB      'SLOW SELF-PLAY.  Q QUITS.  + FASTER, - SLOWER.','$'
COLMS   DB      '  A   B   C   D   E   F   G   H','$'
BORDR   DB      '    +---+---+---+---+---+---+---+---+',0
STGAM   DB      'MATCH: $'
STMOV   DB      'HALF-MOVE: $'
STTRN   DB      'NEXT TURN: $'
STLST   DB      'LAST: $'
STCAP   DB      'CAPTURED: $'
STSPD   DB      'DELAY: $'
SPHLP   DB      '  +/- CHANGE     $'
STYLM   DB      'STYLE: OPERA MINIATURE       $'
WHTMS   DB      'WHITE','$'
BLKMS   DB      'BLACK','$'
THWMS   DB      'WHITE COMPUTER THINKS...     $'
THBMS   DB      'BLACK COMPUTER THINKS...     $'
PLANM   DB      'PLAN: $'
SRCHM   DB      'SEARCH: threats tactics $'
PADMS   DB      '                    $'
END1    DB      'BOOK LINE COMPLETE           $'
END2    DB      'WHITE MATES WITH RD8#        $'
END3    DB      'NEW MATCH WILL START...      $'

INIBD   DB      'rnbqkbnr'
        DB      'pppppppp'
        DB      '........'
        DB      '........'
        DB      '........'
        DB      '........'
        DB      'PPPPPPPP'
        DB      'RNBQKBNR'

MVTAB   DB      52,36,0
        DB      12,28,0
        DB      62,45,0
        DB      11,19,0
        DB      51,35,0
        DB      2,38,0
        DB      35,28,0
        DB      38,45,0
        DB      59,45,0
        DB      19,28,0
        DB      61,34,0
        DB      6,21,0
        DB      45,41,0
        DB      3,12,0
        DB      57,42,0
        DB      10,18,0
        DB      58,30,0
        DB      9,25,0
        DB      42,25,0
        DB      18,25,0
        DB      34,25,0
        DB      1,11,0
        DB      60,58,1
        DB      56,59,0
        DB      0,3,0
        DB      59,11,0
        DB      3,11,0
        DB      63,59,0
        DB      12,20,0
        DB      25,11,0
        DB      21,11,0
        DB      41,1,0
        DB      11,1,0
        DB      59,3,0
        DB      0FFH

SROW    DB      7,7,7,7,7,7,7,7
        DB      9,9,9,9,9,9,9,9
        DB      11,11,11,11,11,11,11,11
        DB      13,13,13,13,13,13,13,13
        DB      15,15,15,15,15,15,15,15
        DB      17,17,17,17,17,17,17,17
        DB      19,19,19,19,19,19,19,19
        DB      21,21,21,21,21,21,21,21
SCOL    DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38
        DB      10,14,18,22,26,30,34,38

SIDE    DB      0
MVH     DB      0
MVL     DB      0
GAMH    DB      0
GAML    DB      0
LFR     DB      0
LTO     DB      0
LFG     DB      0
LPC     DB      '.'
CAPC    DB      '.'
SPD     DB      4
IDX     DB      0
SQI     DB      0
TMP     DB      0
MVPTR   DW      0
BOARD   DS      64
        END     START
