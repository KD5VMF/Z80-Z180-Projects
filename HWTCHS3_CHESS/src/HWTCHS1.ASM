        ORG     0100H
BDOS    EQU     0005H
        JMP     START

START   CALL    INIT
        CALL    DRAW
MAIN    CALL    KEY
        CALL    DLY
        CALL    MOVE
        CALL    DRAW
        JMP     MAIN

INIT    LXI     H,INIBD
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
        MVI     A,' '
        STA     LPC
        RET

MOVE    LHLD    MVPTR
        MOV     A,M
        CPI     0FFH
        JZ      DONE
        STA     LFR
        INX     H
        MOV     A,M
        STA     LTO
        INX     H
        SHLD    MVPTR
        LDA     LFR
        CALL    BPTR
        MOV     A,M
        STA     LPC
        MVI     M,' '
        LDA     LTO
        CALL    BPTR
        LDA     LPC
        MOV     M,A
        LDA     MVL
        INR     A
        STA     MVL
        JNZ     MOV1
        LDA     MVH
        INR     A
        STA     MVH
MOV1    LDA     SIDE
        XRI     1
        STA     SIDE
        RET

DONE    CALL    DRAW
        MVI     B,18
        MVI     C,10
        CALL    GOTO
        LXI     D,DONMS
        CALL    PSTR
        CALL    WAIT
        CALL    INIT
        RET

BPTR    LXI     H,BOARD
        ORA     A
        RZ
        MOV     B,A
BPT1    INX     H
        DCR     B
        JNZ     BPT1
        RET

DRAW    LXI     D,CLRS
        CALL    PSTR
        MVI     B,1
        MVI     C,11
        CALL    GOTO
        LXI     D,TTLMS
        CALL    PSTR
        MVI     B,2
        MVI     C,11
        CALL    GOTO
        LXI     D,SUBMS
        CALL    PSTR
        MVI     B,3
        MVI     C,11
        CALL    GOTO
        LXI     D,HLPMS
        CALL    PSTR
        CALL    STAT
        MVI     B,5
        MVI     C,12
        CALL    GOTO
        LXI     D,COLMS
        CALL    PSTR
        LXI     H,BOARD
        MVI     D,0
DRW1    MOV     A,D
        ADI     6
        MOV     B,A
        MVI     C,8
        CALL    GOTO
        MVI     A,'8'
        SUB     D
        MOV     E,A
        CALL    PCH
        MVI     E,' '
        CALL    PCH
        MVI     E,'|'
        CALL    PCH
        MVI     B,8
DRW2    MVI     E,' '
        CALL    PCH
        MOV     A,M
        CPI     ' '
        JNZ     DRW3
        MVI     E,'.'
        CALL    PCH
        JMP     DRW4
DRW3    MOV     E,A
        CALL    PCH
DRW4    MVI     E,' '
        CALL    PCH
        MVI     E,'|'
        CALL    PCH
        INX     H
        DCR     B
        JNZ     DRW2
        MVI     E,' '
        CALL    PCH
        MVI     A,'8'
        SUB     D
        MOV     E,A
        CALL    PCH
        INR     D
        MOV     A,D
        CPI     8
        JC      DRW1
        MVI     B,14
        MVI     C,12
        CALL    GOTO
        LXI     D,COLMS
        CALL    PSTR
        RET

STAT    MVI     B,16
        MVI     C,8
        CALL    GOTO
        LXI     D,ST1
        CALL    PSTR
        LDA     MVH
        CALL    PHEX
        LDA     MVL
        CALL    PHEX
        LXI     D,ST2
        CALL    PSTR
        LDA     SIDE
        ORA     A
        JZ      STW
        LXI     D,BLKMS
        CALL    PSTR
        JMP     ST3A
STW     LXI     D,WHTMS
        CALL    PSTR
ST3A    LXI     D,ST3
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
        LXI     D,CLRMS
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
        RET

EXIT    LXI     D,NORM
        CALL    PSTR
        JMP     0000H

WAIT    MVI     B,35
WAI1    CALL    KEY
        CALL    DLY
        DCR     B
        JNZ     WAI1
        RET

DLY     PUSH    B
        MVI     B,22
DLY1    MVI     C,0FFH
DLY2    DCR     C
        JNZ     DLY2
        DCR     B
        JNZ     DLY1
        POP     B
        RET

GOTO    PUSH    B
        MVI     E,27
        CALL    PCH
        MVI     E,'['
        CALL    PCH
        MOV     A,B
        CALL    P2D
        MVI     E,';'
        CALL    PCH
        POP     B
        MOV     A,C
        CALL    P2D
        MVI     E,'H'
        CALL    PCH
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

CLRS    DB      27,'[2J',27,'[H',27,'[1;32;40m','$'
NORM    DB      27,'[0m',13,10,'$'
TTLMS   DB      'HWTCHS1  COMPUTER VS COMPUTER CHESS','$'
SUBMS   DB      'CP/M 8080 SAFE ANSI SELF-PLAY BOARD','$'
HLPMS   DB      'AUTO BOOK MATCH.  PRESS Q TO QUIT.','$'
COLMS   DB      '   A   B   C   D   E   F   G   H','$'
ST1     DB      'MOVE:$'
ST2     DB      '   SIDE:$'
ST3     DB      '   LAST:$'
WHTMS   DB      'WHITE','$'
BLKMS   DB      'BLACK','$'
CLRMS   DB      '          $'
DONMS   DB      'BOOK GAME COMPLETE - STARTING NEW MATCH','$'

INIBD   DB      'rnbqkbnr'
        DB      'pppppppp'
        DB      '        '
        DB      '        '
        DB      '        '
        DB      '        '
        DB      'PPPPPPPP'
        DB      'RNBQKBNR'

MVTAB   DB      52,36
        DB      12,28
        DB      62,45
        DB      1,18
        DB      61,34
        DB      5,26
        DB      50,42
        DB      6,21
        DB      51,43
        DB      11,19
        DB      58,38
        DB      15,23
        DB      38,31
        DB      14,30
        DB      31,46
        DB      21,31
        DB      57,51
        DB      31,46
        DB      55,46
        DB      3,12
        DB      59,52
        DB      8,24
        DB      48,32
        DB      0,16
        DB      56,40
        DB      26,35
        DB      34,43
        DB      18,24
        DB      40,48
        DB      4,6
        DB      0FFH

SIDE    DB      0
MVH     DB      0
MVL     DB      0
LFR     DB      0
LTO     DB      0
LPC     DB      ' '
MVPTR   DW      0
BOARD   DS      64
        END     START
