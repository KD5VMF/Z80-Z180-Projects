;HWTWHT49.ASM  WHITE PLAYER FOR TWO-Z180 PORT-B CHESS
;TWO SMALL COMPUTER CENTRAL Z180 ROMWBW CP/M SYSTEMS.
;PORT A=EACH MACHINE'S TERMINAL. PORT B=Z180 TO Z180 LINK.
;NULL MODEM ONLY: TXB-RXB, RXB-TXB, GND-GND. NO RTS/CTS.
;TERMINAL ONLY. NO LCD. NO LED I/O.
;REV49: BLACK FIRST. VARIED TOURNAMENT BOOK, NOT FORCED 50/50.
;BASED ON FIRST GOOD LINK: HWTLINK30 RX-EXIT FIX.
        ORG     0100H
BDOS    EQU     0005H
DEFLC   EQU     1903H
MLEN    EQU     020H
        JMP     START
START   LXI     SP,STKE
        MVI     A,001H
        STA     UNI
        CALL    CLR
        LXI     H,DEFLC
        SHLD    LCHR
        XRA     A
        STA     TT
        CALL    QRA
        CALL    INIT
        CALL    SETB
        CALL    DRAW
        CALL    FIRST
LOOP    CALL    KEY
        LDA     PHS
        CPI     'T'
        JZ      DOTX
        CPI     'G'
        JZ      DOGP
        CALL    RXLP
        CALL    TICK
        JMP     LEND
DOTX    CALL    SEND
        JMP     LEND
DOGP    CALL    GAP1
LEND    CALL    DLY
        JMP     LOOP
CLR     XRA     A
        STA     ST
        STA     LB
        STA     ISB
        STA     HER
        STA     OER
        STA     TMR
        STA     GCT
        STA     DFLG
        STA     SENT
        STA     MIX
        STA     LASTI
        STA     LSTO
        LXI     H,0000H
        SHLD    TXP
        SHLD    TXB
        SHLD    RXP
        SHLD    RXB
        SHLD    GOOD
        SHLD    BAD
        SHLD    MISS
        SHLD    RETR
        SHLD    MOVS
        SHLD    MYCP
        SHLD    OPCP
        SHLD    TGAM
        SHLD    WWIN
        SHLD    BWIN
        MVI     A,001H
        STA     MYSQ
        MVI     A,002H
        STA     EXPS
        MVI     A,'R'
        STA     PHS
        RET
SETB    LXI     H,BDINI
        LXI     D,BRD
        MVI     B,040H
SB1     MOV     A,M
        STAX    D
        INX     H
        INX     D
        DCR     B
        JNZ     SB1
        RET
FIRST   CALL    NWMV
        MVI     A,'T'
        STA     PHS
        CALL    DRAW
        RET

; ------------------------------------------------------------
; LINK ENGINE - HWTLINK30/37 STYLE
; ------------------------------------------------------------
GAP1    LDA     GCT
        ORA     A
        JZ      GP2
        DCR     A
        STA     GCT
        RET
GP2     CALL    NWMV
        MVI     A,'T'
        STA     PHS
        CALL    DRAW
        RET
TICK    LDA     PHS
        CPI     'R'
        RNZ
        LDA     SENT
        ORA     A
        RZ
        LDA     TMR
        INR     A
        STA     TMR
        CPI     002H
        RC
        XRA     A
        STA     TMR
        CALL    IRET
        MVI     A,'T'
        STA     PHS
        CALL    DRAW
        RET
MKPK    MVI     A,055H
        STA     PB0
        MVI     A,0AAH
        STA     PB1
        MVI     A,'M'
        STA     PB2
        LDA     MYSQ
        STA     PB3
        LDA     MF
        STA     PB4
        LDA     MT
        STA     PB5
        LDA     PCE
        STA     PB6
        CALL    BCHK
        STA     PB7
        CALL    CKTX
        RET
MKNG    MVI     A,055H
        STA     PB0
        MVI     A,0AAH
        STA     PB1
        MVI     A,'N'
        STA     PB2
        LDA     MYSQ
        STA     PB3
        XRA     A
        STA     PB4
        STA     PB5
        MVI     A,'W'
        STA     PB6
        CALL    BCHK
        STA     PB7
        CALL    CKTX
        RET
MKHEL   MVI     A,055H
        STA     PB0
        MVI     A,0AAH
        STA     PB1
        MVI     A,'H'
        STA     PB2
        XRA     A
        STA     PB3
        STA     PB4
        STA     PB5
        MVI     A,'W'
        STA     PB6
        CALL    BCHK
        STA     PB7
        CALL    CKTX
        RET
CKTX    LXI     H,PB0
        MVI     B,008H
        XRA     A
CT1     XRA     M
        INX     H
        DCR     B
        JNZ     CT1
        STA     PB8
        RET
SEND    LXI     H,PB0
        MVI     B,009H
SN1     MOV     A,M
        PUSH    H
        PUSH    B
        CALL    OUTC
        POP     B
        POP     H
        INX     H
        DCR     B
        JNZ     SN1
        CALL    ITXP
        LDA     PB3
        STA     LSTO
        MVI     A,001H
        STA     SENT
        XRA     A
        STA     TMR
        STA     ST
        LDA     PB2
        CPI     'N'
        JZ      SNGW
        MVI     A,'R'
        STA     PHS
        CALL    DRAW
        RET
SNGW    MVI     A,018H
        STA     GCT
        MVI     A,'G'
        STA     PHS
        CALL    DRAW
        RET
RXLP    MVI     A,020H
        STA     CNT
RX1     CALL    HST
        STA     ISB
        ORA     A
        RZ
        CALL    HBI
        STA     LB
        CALL    IRXB
        CALL    PARS
        LDA     PHS
        CPI     'G'
        RZ
        CPI     'T'
        RZ
        LDA     CNT
        DCR     A
        STA     CNT
        JNZ     RX1
        RET
PARS    LDA     ST
        ORA     A
        JZ      PA0
        CPI     001H
        JZ      PA1
        CPI     008H
        JZ      PA8
        CALL    SAVR
        LDA     ST
        INR     A
        STA     ST
        RET
PA0     LDA     LB
        CPI     055H
        RNZ
        CALL    SAVR
        MVI     A,001H
        STA     ST
        RET
PA1     LDA     LB
        CPI     0AAH
        JZ      PA1G
        XRA     A
        STA     ST
        CALL    IBAD
        CALL    DRAW
        RET
PA1G    CALL    SAVR
        MVI     A,002H
        STA     ST
        RET
PA8     CALL    SAVR
        XRA     A
        STA     ST
        CALL    CKRX
        ORA     A
        JZ      PGOD
        CALL    IBAD
        CALL    DRAW
        RET
PGOD    CALL    IRXP
        CALL    PKIN
        CALL    DRAW
        RET
SAVR    LXI     H,RB0
        LDA     ST
        MOV     E,A
        MVI     D,000H
        DAD     D
        LDA     LB
        MOV     M,A
        RET
CKRX    LXI     H,RB0
        MVI     B,008H
        XRA     A
CR1     XRA     M
        INX     H
        DCR     B
        JNZ     CR1
        MOV     B,A
        LDA     RB8
        CMP     B
        JZ      COK
        MVI     A,001H
        RET
COK     XRA     A
        RET
PKIN    LDA     RB3
        MOV     B,A
        LDA     EXPS
        CMP     B
        JZ      PNEW
        LDA     LASTI
        CMP     B
        JZ      PDUP
        CALL    IMIS
        RET
PDUP    CALL    IRET
        MVI     A,'T'
        STA     PHS
        RET
PNEW    LDA     RB3
        STA     LASTI
        ADI     002H
        STA     EXPS
        LDA     RB2
        CPI     'M'
        JZ      PMOV
        CPI     'N'
        JZ      PNRW
        CALL    IMIS
        RET
PMOV    LDA     RB4
        STA     MF
        LDA     RB5
        STA     MT
        CALL    APMV
        CALL    IGOD
        CALL    NWMV
        MVI     A,'T'
        STA     PHS
        RET
PNRW    CALL    RNGM
        CALL    NWMV
        MVI     A,'T'
        STA     PHS
        RET
OUTC    STA     LB
        MOV     E,A
        CALL    HBO
        CALL    ITXB
        CALL    SDLY
        RET
; ------------------------------------------------------------
; BOARD AND MOVE ENGINE
; Local moves only use a real piece from our current board.
; This prevents stale received piece bytes from turning pieces into Ks/etc.
; Received moves may use packet piece byte only if our source square is empty.
; ------------------------------------------------------------
NWMV    XRA     A
        STA     TRY
NW0     LDA     MIX
        CPI     MLEN
        JC      NW1
        XRA     A
        STA     MIX
NW1     MOV     E,A
        MVI     D,000H
        LXI     H,MVT
        DAD     D
        DAD     D
        MOV     A,M
        STA     MF
        INX     H
        MOV     A,M
        STA     MT
        LDA     MIX
        INR     A
        STA     MIX
        CALL    VALM
        ORA     A
        JNZ     NWG
        LDA     TRY
        INR     A
        STA     TRY
        CPI     MLEN
        JC      NW0
        CALL    LNGM
        RET
NWG     CALL    DOMV
        CALL    MKPK
        LDA     MYSQ
        ADI     002H
        STA     MYSQ
        RET
VALM    LDA     MF
        CALL    GETS
        CALL    OWNP
        ORA     A
        JZ      VBAD
        LDA     MT
        CALL    GETS
        CALL    OWNP
        ORA     A
        JNZ     VBAD
        MVI     A,0FFH
        RET
VBAD    XRA     A
        RET
DOMV    LDA     MF
        MOV     E,A
        MVI     D,000H
        LXI     H,BRD
        DAD     D
        MOV     A,M
        STA     PCE
        MOV     C,A
        MVI     M,'.'
        LDA     MT
        MOV     E,A
        MVI     D,000H
        LXI     H,BRD
        DAD     D
        MOV     A,M
        CPI     '.'
        JZ      DNOC
        MVI     A,001H
        STA     CAPF
        JMP     DCAP
DNOC    XRA     A
        STA     CAPF
DCAP    MOV     M,C
        LDA     CAPF
        ORA     A
        JZ      DNX
        CALL    IMYC
DNX     CALL    IMOV
        CALL    GCHK
        RET
APMV    LDA     RB6
        CPI     000H
        JZ      AP0
        CPI     '.'
        JZ      AP0
        STA     PCE
        MOV     C,A
        JMP     AP2
AP0     LDA     MF
        MOV     E,A
        MVI     D,000H
        LXI     H,BRD
        DAD     D
        MOV     A,M
        CPI     '.'
        JNZ     AP1
        MVI     A,'?'
AP1     STA     PCE
        MOV     C,A
AP2     LDA     MF
        MOV     E,A
        MVI     D,000H
        LXI     H,BRD
        DAD     D
        MVI     M,'.'
        LDA     MT
        MOV     E,A
        MVI     D,000H
        LXI     H,BRD
        DAD     D
        MOV     A,M
        CPI     '.'
        JZ      ANOC
        MVI     A,001H
        STA     CAPF
        JMP     ACAP
ANOC    XRA     A
        STA     CAPF
ACAP    MOV     M,C
        LDA     CAPF
        ORA     A
        JZ      ANX
        CALL    IOPC
ANX     CALL    IMOV
        CALL    BCHK
        MOV     B,A
        LDA     RB7
        CMP     B
        JZ      ANOK
        CALL    IMIS
ANOK    CALL    GCHK
        RET
; synchronized new-game reset.  Packet type N keeps both boards aligned.
LNGM    CALL    SCOR
        CALL    RSET
        CALL    MKNG
        LDA     MYSQ
        ADI     002H
        STA     MYSQ
        RET
RNGM    CALL    SCOR
        CALL    RSET
        RET
RSET    CALL    SETB
        XRA     A
        STA     SENT
        STA     CAPF
        STA     MF
        STA     MT
        LHLD    TGAM
        MOV     A,L
        ANI     007H
        ADD     A
        ADD     A
        STA     MIX
        LXI     H,0000H
        SHLD    MOVS
        SHLD    MYCP
        SHLD    OPCP
        MVI     A,'.'
        STA     PCE
        RET
SCOR    CALL    IGAM
        LHLD    MYCP
        MOV     B,L
        LHLD    OPCP
        MOV     A,L
        CMP     B
        JC      SWHT
        JZ      STIE
        CALL    IBWN
        RET
SWHT    CALL    IWWN
STIE    RET
GETS    MOV     E,A
        MVI     D,000H
        LXI     H,BRD
        DAD     D
        MOV     A,M
        RET
BCHK    LXI     H,BRD
        MVI     B,040H
        XRA     A
BC1     XRA     M
        INX     H
        DCR     B
        JNZ     BC1
        RET
OWNP    CPI     'P'
        JZ      OYES
        CPI     'N'
        JZ      OYES
        CPI     'B'
        JZ      OYES
        CPI     'R'
        JZ      OYES
        CPI     'Q'
        JZ      OYES
        CPI     'K'
        JZ      OYES
        XRA     A
        RET
OYES    MVI     A,001H
        RET
; ------------------------------------------------------------
; KEYBOARD AND HBIOS
; KEYBOARD AND HBIOS
; ------------------------------------------------------------
KEY     MVI     C,006H
        MVI     E,0FFH
        CALL    BDOS
        ORA     A
        RZ
        CPI     'Q'
        JZ      EXIT
        CPI     'q'
        JZ      EXIT
        CPI     003H
        JZ      EXIT
        CPI     01BH
        JZ      EXIT
        CPI     'R'
        JZ      KRES
        CPI     'r'
        JZ      KRES
        CPI     'I'
        JZ      KINI
        CPI     'i'
        JZ      KINI
        CPI     'A'
        JZ      KAGN
        CPI     'a'
        JZ      KAGN
        CPI     '0'
        JC      KX
        CPI     '8'
        JNC     KX
        SUI     '0'
        STA     UNI
KINI    CALL    QRA
        CALL    INIT
        CALL    DRAW
        RET
KRES    CALL    CLR
        CALL    QRA
        CALL    INIT
        CALL    SETB
        CALL    DRAW
        CALL    FIRST
        RET
KAGN    MVI     A,'T'
        STA     PHS
KX      RET
EXIT    LXI     H,NORM
        CALL    PS
        JMP     0000H
QRA     MVI     C,000H
        MVI     B,005H
        CALL    HBC
        STA     QRS
        ORA     A
        RNZ
        MOV     A,L
        STA     TT
        MOV     H,D
        MOV     L,E
        SHLD    LCHR
        RET
INIT    LDA     UNI
        MOV     C,A
        MVI     B,004H
        LHLD    LCHR
        MOV     D,H
        MOV     E,L
        LDA     TT
        MOV     L,A
        CALL    HBC
        STA     RES
        RET
HST     LDA     UNI
        MOV     C,A
        MVI     B,002H
        CALL    HBC
        STA     HER
        MOV     A,E
        RET
HBI     LDA     UNI
        MOV     C,A
        MVI     B,000H
        CALL    HBC
        STA     HER
        MOV     A,E
        RET
HBO     LDA     UNI
        MOV     C,A
        MVI     B,001H
        CALL    HBC
        STA     OER
        RET
HBC     DB      0CFH
        RET
ITXP    LHLD    TXP
        INX     H
        SHLD    TXP
        RET
ITXB    LHLD    TXB
        INX     H
        SHLD    TXB
        RET
IRXP    LHLD    RXP
        INX     H
        SHLD    RXP
        RET
IRXB    LHLD    RXB
        INX     H
        SHLD    RXB
        RET
IGOD    LHLD    GOOD
        INX     H
        SHLD    GOOD
        RET
IBAD    LHLD    BAD
        INX     H
        SHLD    BAD
        RET
IMIS    LHLD    MISS
        INX     H
        SHLD    MISS
        RET
IRET    LHLD    RETR
        INX     H
        SHLD    RETR
        RET
IMOV    LHLD    MOVS
        INX     H
        SHLD    MOVS
        RET
IMYC    LHLD    MYCP
        INX     H
        SHLD    MYCP
        RET
IOPC    LHLD    OPCP
        INX     H
        SHLD    OPCP
        RET
IGAM    LHLD    TGAM
        INX     H
        SHLD    TGAM
        RET
IWWN    LHLD    WWIN
        INX     H
        SHLD    WWIN
        RET
IBWN    LHLD    BWIN
        INX     H
        SHLD    BWIN
        RET
GCHK    RET
; ------------------------------------------------------------
; TERMINAL DISPLAY - REV40
; Static frame is drawn once.  Later updates use absolute
; cursor positions and clear-to-end-of-line. This prevents
; scrolling/leftover text and greatly reduces redraw flicker.
; ------------------------------------------------------------
DRAW    LDA     DFLG
        ORA     A
        JNZ     DUPD
        LXI     H,CLS
        CALL    PS
        MVI     A,001H
        STA     DFLG
        CALL    FRAM
DUPD    LXI     H,GRN
        CALL    PS
        CALL    R8
        CALL    R7
        CALL    R6
        CALL    R5
        CALL    R4
        CALL    R3
        CALL    R2
        CALL    R1
        LXI     H,UEND
        CALL    PS
        RET
FRAM    LXI     H,CYN
        CALL    PS
        LXI     H,P01
        CALL    PS
        LXI     H,TOP
        CALL    PEOL
        LXI     H,P02
        CALL    PS
        LXI     H,YEL
        CALL    PS
        LXI     H,TIT
        CALL    PEOL
        LXI     H,CYN
        CALL    PS
        LXI     H,P03
        CALL    PS
        LXI     H,SEP
        CALL    PEOL
        LXI     H,P04
        CALL    PS
        LXI     H,WHT
        CALL    PS
        LXI     H,HDR
        CALL    PEOL
        LXI     H,CYN
        CALL    PS
        LXI     H,P13
        CALL    PS
        LXI     H,SEP
        CALL    PEOL
        LXI     H,P14
        CALL    PS
        LXI     H,WHT
        CALL    PS
        LXI     H,FOOT
        CALL    PEOL
        LXI     H,CYN
        CALL    PS
        LXI     H,P15
        CALL    PS
        LXI     H,BOT
        CALL    PEOL
        RET
R8      LXI     H,P05
        CALL    PS
        LXI     H,RA8
        CALL    PS
        LXI     H,BRD
        CALL    PROW
        LXI     H,R8A
        CALL    PS
        LDA     PHS
        CALL    PC
        LXI     H,R8B
        CALL    PS
        LDA     UNI
        ADI     '0'
        CALL    PC
        LXI     H,R8C
        CALL    PS
        LHLD    LCHR
        CALL    P4
        LXI     H,R8D
        CALL    PEOL
        RET
R7      LXI     H,P06
        CALL    PS
        LXI     H,RA7
        CALL    PS
        LXI     H,BRD+8
        CALL    PROW
        LXI     H,R7A
        CALL    PS
        LDA     MYSQ
        CALL    P2
        LXI     H,R7B
        CALL    PS
        LDA     LASTI
        CALL    P2
        LXI     H,R7C
        CALL    PEOL
        RET
R6      LXI     H,P07
        CALL    PS
        LXI     H,RA6
        CALL    PS
        LXI     H,BRD+16
        CALL    PROW
        LXI     H,R6A
        CALL    PS
        LDA     MF
        CALL    PSQ
        MVI     A,'-'
        CALL    PC
        LDA     MT
        CALL    PSQ
        LXI     H,R6B
        CALL    PS
        LDA     PCE
        CALL    PC
        LXI     H,R6C
        CALL    PEOL
        RET
R5      LXI     H,P08
        CALL    PS
        LXI     H,RA5
        CALL    PS
        LXI     H,BRD+24
        CALL    PROW
        LXI     H,R5A
        CALL    PS
        LHLD    TXP
        CALL    P4
        LXI     H,R5B
        CALL    PS
        LHLD    RXP
        CALL    P4
        LXI     H,R5C
        CALL    PEOL
        RET
R4      LXI     H,P09
        CALL    PS
        LXI     H,RA4
        CALL    PS
        LXI     H,BRD+32
        CALL    PROW
        LXI     H,R4A
        CALL    PS
        LHLD    TXB
        CALL    P4
        LXI     H,R4B
        CALL    PS
        LHLD    RXB
        CALL    P4
        LXI     H,R4C
        CALL    PEOL
        RET
R3      LXI     H,P10
        CALL    PS
        LXI     H,RA3
        CALL    PS
        LXI     H,BRD+40
        CALL    PROW
        LXI     H,R3A
        CALL    PS
        LHLD    GOOD
        CALL    P4
        LXI     H,R3B
        CALL    PS
        LHLD    BAD
        CALL    P4
        LXI     H,R3C
        CALL    PS
        LHLD    MISS
        CALL    P4
        LXI     H,R3D
        CALL    PS
        LHLD    RETR
        CALL    P4
        LXI     H,R3E
        CALL    PEOL
        RET
R2      LXI     H,P11
        CALL    PS
        LXI     H,RA2
        CALL    PS
        LXI     H,BRD+48
        CALL    PROW
        LXI     H,R2A
        CALL    PS
        LDA     LB
        CALL    P2
        LXI     H,R2B
        CALL    PS
        LDA     ISB
        CALL    P2
        LXI     H,R2C
        CALL    PS
        LDA     HER
        CALL    P2
        LXI     H,R2D
        CALL    PS
        LDA     OER
        CALL    P2
        LXI     H,R2E
        CALL    PEOL
        RET
R1      LXI     H,P12
        CALL    PS
        LXI     H,RA1
        CALL    PS
        LXI     H,BRD+56
        CALL    PROW
        LXI     H,R1A
        CALL    PS
        LHLD    TGAM
        CALL    P4
        LXI     H,R1B
        CALL    PS
        LHLD    WWIN
        CALL    P4
        LXI     H,R1C
        CALL    PS
        LHLD    BWIN
        CALL    P4
        LXI     H,R1D
        CALL    PEOL
        RET
PROW    MVI     B,008H
PR1     MOV     A,M
        CALL    PC
        MVI     A,' '
        CALL    PC
        INX     H
        DCR     B
        JNZ     PR1
        RET
PSQ     MOV     C,A
        MVI     B,000H
SQ1     MOV     A,C
        CPI     008H
        JC      SQ2
        SUI     008H
        MOV     C,A
        INR     B
        JMP     SQ1
SQ2     MOV     A,C
        ADI     'a'
        CALL    PC
        MVI     A,'8'
        SUB     B
        CALL    PC
        RET
PS      MOV     A,M
        ORA     A
        RZ
        CALL    PC
        INX     H
        JMP     PS
PC      PUSH    PSW
        PUSH    B
        PUSH    D
        PUSH    H
        MOV     E,A
        MVI     C,002H
        CALL    BDOS
        POP     H
        POP     D
        POP     B
        POP     PSW
        RET
PEOL    CALL    PS
        LXI     H,EOL
        CALL    PS
        RET
PL      CALL    PS
        LXI     H,EOL
        CALL    PS
        CALL    CR
        RET
CR      MVI     A,00DH
        CALL    PC
        MVI     A,00AH
        CALL    PC
        RET
P4      MOV     A,H
        CALL    P2
        MOV     A,L
        CALL    P2
        RET
P2      PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        ANI     00FH
        CALL    PN
        POP     PSW
        ANI     00FH
PN      CPI     00AH
        JC      PN1
        ADI     007H
PN1     ADI     '0'
        CALL    PC
        RET
SDLY    PUSH    B
        MVI     B,020H
SD1     DCR     B
        JNZ     SD1
        POP     B
        RET
DLY     PUSH    B
        MVI     B,00AH
DL1     MVI     C,0F0H
DL2     DCR     C
        JNZ     DL2
        DCR     B
        JNZ     DL1
        POP     B
        RET
; ------------------------------------------------------------
; STRINGS AND DATA
; ------------------------------------------------------------
CLS     DB      01BH,'[','2','J',01BH,'[','H'
        DB      01BH,'[','1',';','3','2',';','4','0','m'
        DB      01BH,'[','?','2','5','l',0
HOME    DB      01BH,'[','H',0
NORM    DB      01BH,'[','0','m',01BH,'[','?','2','5','h',00DH,00AH,0
GRN     DB      01BH,'[','1',';','3','2','m',0
CYN     DB      01BH,'[','1',';','3','6','m',0
WHT     DB      01BH,'[','1',';','3','7','m',0
YEL     DB      01BH,'[','1',';','3','3','m',0
EOL     DB      01BH,'[','K',0
P01     DB      01BH,'[','1',';','1','H',0
P02     DB      01BH,'[','2',';','1','H',0
P03     DB      01BH,'[','3',';','1','H',0
P04     DB      01BH,'[','4',';','1','H',0
P05     DB      01BH,'[','5',';','1','H',0
P06     DB      01BH,'[','6',';','1','H',0
P07     DB      01BH,'[','7',';','1','H',0
P08     DB      01BH,'[','8',';','1','H',0
P09     DB      01BH,'[','9',';','1','H',0
P10     DB      01BH,'[','1','0',';','1','H',0
P11     DB      01BH,'[','1','1',';','1','H',0
P12     DB      01BH,'[','1','2',';','1','H',0
P13     DB      01BH,'[','1','3',';','1','H',0
P14     DB      01BH,'[','1','4',';','1','H',0
P15     DB      01BH,'[','1','5',';','1','H',0
TOP     DB      '+-----------------------------'
        DB      '------------------------------'
        DB      '---+',0
SEP     DB      '+-----------------------------'
        DB      '------------------------------'
        DB      '---+',0
BOT     DB      '+-----------------------------'
        DB      '------------------------------'
        DB      '---+',0
HDR     DB      '| BOARD                 | LINK'
        DB      ' AND GAME STATUS              '
        DB      '   |',0
RA8     DB      '| 8  ',0
RA7     DB      '| 7  ',0
RA6     DB      '| 6  ',0
RA5     DB      '| 5  ',0
RA4     DB      '| 4  ',0
RA3     DB      '| 3  ',0
RA2     DB      '| 2  ',0
RA1     DB      '| 1  ',0
R8A     DB      '| Phase:',0
R8B     DB      '  Unit:',0
R8C     DB      '  LC:',0
R8D     DB      '                |',0
R7A     DB      '| SendSeq:',0
R7B     DB      '  RecvSeq:',0
R7C     DB      '                  |',0
R6A     DB      '| Move:',0
R6B     DB      '  Piece:',0
R6C     DB      '                     |',0
R5A     DB      '| Packets TX:',0
R5B     DB      '  RX:',0
R5C     DB      '                |',0
R4A     DB      '| Bytes   TX:',0
R4B     DB      '  RX:',0
R4C     DB      '                |',0
R3A     DB      '| Good:',0
R3B     DB      ' Bad:',0
R3C     DB      ' Miss:',0
R3D     DB      ' Retry:',0
R3E     DB      ' |',0
R2A     DB      '| HBIOS Last:',0
R2B     DB      ' IST:',0
R2C     DB      ' HA:',0
R2D     DB      ' OA:',0
R2E     DB      '        |',0
R1A     DB      '| Total games:',0
R1B     DB      ' W wins:',0
R1C     DB      ' B wins:',0
R1D     DB      '|',0
FOOT    DB      '|    a b c d e f g h   | Q qui'
        DB      't   R reset   I init   A resen'
        DB      'd  |',0
UEND    DB      01BH,'[','1','6',';','1','H',0
TIT     DB      '| HWTWHT49  WHITE COMPUTER    '
        DB      ' Z180 VS Z180 PORT-B CHESS    '
        DB      '   |',0
; move book: from,to square indexes. a8=00, h1=3F
MVT     DB      34H,24H,3EH,2DH,3DH,22H,33H,2BH,32H,2AH,39H,33H,37H,2FH,30H,20H
        DB      3AH,1EH,31H,21H,20H,18H,3BH,34H,36H,26H,22H,29H,2DH,27H,27H,16H
        DB      34H,2CH,38H,28H,28H,2AH,33H,2DH,3CH,33H,2DH,1EH,1EH,0DH,2CH,1CH
        DB      2AH,0AH,33H,3AH,29H,0DH,3AH,39H,26H,1EH,2FH,27H,35H,25H,39H,38H
BDINI   DB      072H,06EH,062H,071H,06BH,062H,06EH,072H
        DB      070H,070H,070H,070H,070H,070H,070H,070H
        DB      '........'
        DB      '........'
        DB      '........'
        DB      '........'
        DB      'PPPPPPPP'
        DB      'RNBQKBNR'

DFLG    DB      0
UNI     DB      0
PHS     DB      0
ST      DB      0
MYSQ    DB      0
EXPS    DB      0
LASTI   DB      0
LSTO    DB      0
MIX     DB      0
MF      DB      0
MT      DB      0
PCE     DB      0
LB      DB      0
ISB     DB      0
RES     DB      0
QRS     DB      0
HER     DB      0
OER     DB      0
CNT     DB      0
TMR     DB      0
TT      DB      0
GCT     DB      0
SENT    DB      0
TRY     DB      0
CAPF    DB      0
LCHR    DW      0
TXP     DW      0
TXB     DW      0
RXP     DW      0
RXB     DW      0
GOOD    DW      0
BAD     DW      0
MISS    DW      0
RETR    DW      0
MOVS    DW      0
MYCP    DW      0
OPCP    DW      0
TGAM    DW      0
WWIN    DW      0
BWIN    DW      0
PB0     DB      0
PB1     DB      0
PB2     DB      0
PB3     DB      0
PB4     DB      0
PB5     DB      0
PB6     DB      0
PB7     DB      0
PB8     DB      0
RB0     DB      0
RB1     DB      0
RB2     DB      0
RB3     DB      0
RB4     DB      0
RB5     DB      0
RB6     DB      0
RB7     DB      0
RB8     DB      0
BRD     DB      072H,06EH,062H,071H,06BH,062H,06EH,072H
        DB      070H,070H,070H,070H,070H,070H,070H,070H
        DB      '........'
        DB      '........'
        DB      '........'
        DB      '........'
        DB      'PPPPPPPP'
        DB      'RNBQKBNR'
STK     DS      256
STKE    DB      0
        END     START
