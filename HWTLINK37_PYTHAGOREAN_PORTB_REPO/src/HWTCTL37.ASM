;HWTCTL37.ASM  CONTROLLER PYTHAG LINK TERMINAL ONLY
;TWO Z180 ROMWBW CP/M SYSTEMS. PORT A=TERMINAL. PORT B=LINK.
;NO LCD. NO LED I/O. SAFE FOR SC131.
;BASED ON FIRST GOOD LINK: HWTLINK30 RX-EXIT FIX.
        ORG     0100H
BDOS    EQU     0005H
DEFLC   EQU     1903H
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
        LXI     H,CLS
        CALL    PS
        CALL    MAKEQ
        CALL    DRAW
        CALL    SEND
LOOP    CALL    KEY
        LDA     PHS
        CPI     'T'
        JZ      DOTX
        CPI     'G'
        JZ      DOGP
        CALL    RXLP
        JMP     LEND
DOTX    CALL    SEND
        JMP     LEND
DOGP    CALL    GAP1
LEND    CALL    DLY
        JMP     LOOP
CLR     XRA     A
        STA     ST
        STA     SQ
        STA     LB
        STA     ISB
        STA     HER
        STA     OER
        STA     TMR
        STA     VOK
        STA     GCT
        STA     DFLG
        LXI     H,0000H
        SHLD    TXP
        SHLD    TXB
        SHLD    RXP
        SHLD    RXB
        SHLD    GOOD
        SHLD    BAD
        SHLD    MISS
        SHLD    RETR
        SHLD    EXPL
        SHLD    ANSL
        MVI     A,017H
        STA     QA
        MVI     A,009H
        STA     QB
        MVI     A,'T'
        STA     PHS
        RET
GAP1    LDA     GCT
        ORA     A
        JZ      GP2
        DCR     A
        STA     GCT
        RET
GP2     CALL    NXTQ
        CALL    MAKEQ
        MVI     A,'T'
        STA     PHS
        CALL    DRAW
        RET
NXTQ    LDA     SQ
        INR     A
        STA     SQ
        LDA     QA
        ADI     007H
NQ1     CPI     064H
        JC      NQ2
        SUI     063H
        JMP     NQ1
NQ2     ORA     A
        JNZ     NQ3
        INR     A
NQ3     STA     QA
        LDA     QB
        ADI     005H
NQ4     CPI     064H
        JC      NQ5
        SUI     061H
        JMP     NQ4
NQ5     ORA     A
        JNZ     NQ6
        INR     A
NQ6     STA     QB
        RET
MULQ    LXI     H,0000H
        LDA     QA
        MOV     E,A
        MVI     D,000H
        MOV     B,A
        CALL    MAD
        LDA     QB
        MOV     E,A
        MVI     D,000H
        MOV     B,A
        CALL    MAD
        SHLD    EXPL
        RET
MAD     MOV     A,B
        ORA     A
        RZ
        DAD     D
        DCR     B
        JMP     MAD
MAKEQ   CALL    MULQ
        MVI     A,055H
        STA     PB0
        MVI     A,0AAH
        STA     PB1
        MVI     A,'Q'
        STA     PB2
        STA     PTY
        LDA     SQ
        STA     PB3
        LDA     QA
        STA     PB4
        LDA     QB
        STA     PB5
        XRA     A
        STA     PB6
        STA     PB7
        STA     ANSL
        STA     ANSH
        STA     VOK
        CALL    CKTX
        RET
MAKEV   MVI     A,055H
        STA     PB0
        MVI     A,0AAH
        STA     PB1
        MVI     A,'V'
        STA     PB2
        STA     PTY
        LDA     SQ
        STA     PB3
        LDA     QA
        STA     PB4
        LDA     QB
        STA     PB5
        LDA     VOK
        STA     PB6
        XRA     A
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
        XRA     A
        STA     TMR
        STA     ST
        LDA     PTY
        CPI     'Q'
        JZ      SQ1
        CPI     'V'
        JZ      SV1
        MVI     A,'R'
        STA     PHS
        CALL    DRAW
        RET
SQ1     MVI     A,'R'
        STA     PHS
        CALL    DRAW
        RET
SV1     MVI     A,018H
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
PKIN    LDA     RB2
        CPI     'A'
        JZ      PKA
        CALL    IMIS
        RET
PKA     LDA     RB3
        MOV     B,A
        LDA     SQ
        CMP     B
        JZ      PK1
        CALL    IMIS
        RET
PK1     LDA     RB4
        MOV     B,A
        LDA     QA
        CMP     B
        JZ      PK2
        CALL    IMIS
        RET
PK2     LDA     RB5
        MOV     B,A
        LDA     QB
        CMP     B
        JZ      PK3
        CALL    IMIS
        RET
PK3     LDA     RB6
        STA     ANSL
        LDA     RB7
        STA     ANSH
        CALL    MULQ
        LDA     ANSL
        MOV     B,A
        LDA     EXPL
        CMP     B
        JNZ     PKB
        LDA     ANSH
        MOV     B,A
        LDA     EXPH
        CMP     B
        JNZ     PKB
        MVI     A,001H
        STA     VOK
        CALL    IGOD
        JMP     PKV
PKB     XRA     A
        STA     VOK
        CALL    IBAD
PKV     CALL    MAKEV
        MVI     A,'T'
        STA     PHS
        RET
OUTC    STA     LB
        MOV     E,A
        CALL    HBO
        CALL    ITXB
        CALL    SDLY
        RET
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
        CALL    MAKEQ
        MVI     A,'T'
        STA     PHS
        CALL    DRAW
        RET
KAGN    CALL    MAKEQ
        MVI     A,'T'
        STA     PHS
        CALL    DRAW
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
DRAW    LDA     DFLG
        ORA     A
        JNZ     DRU
        LXI     H,CLS
        CALL    PS
        CALL    FRAME
        MVI     A,001H
        STA     DFLG
DRU     CALL    UPD
        RET
FRAME   LXI     H,CYN
        CALL    PS
        LXI     H,TOP
        CALL    PL
        LXI     H,TIT
        CALL    PL
        LXI     H,ROL
        CALL    PL
        LXI     H,SEP
        CALL    PL
        LXI     H,YEL
        CALL    PS
        LXI     H,JOB1
        CALL    PL
        LXI     H,JOB2
        CALL    PL
        LXI     H,RES1
        CALL    PL
        LXI     H,RES2
        CALL    PL
        LXI     H,CYN
        CALL    PS
        LXI     H,SEP
        CALL    PL
        LXI     H,LNK1
        CALL    PL
        LXI     H,LNK2
        CALL    PL
        LXI     H,LNK3
        CALL    PL
        LXI     H,HBIO
        CALL    PL
        LXI     H,SEP
        CALL    PL
        LXI     H,KEYS
        CALL    PL
        LXI     H,BOT
        CALL    PL
        RET
PL      CALL    PS
        CALL    CR
        RET
UPD     LXI     H,GRN
        CALL    PS
        LXI     H,APHS
        CALL    PS
        LDA     PHS
        CALL    PC
        LXI     H,AUNI
        CALL    PS
        LDA     UNI
        ADI     '0'
        CALL    PC
        LXI     H,ALC
        CALL    PS
        LHLD    LCHR
        CALL    P4
        LXI     H,ASQ
        CALL    PS
        LDA     SQ
        CALL    P2
        LXI     H,AQA
        CALL    PS
        LDA     QA
        CALL    P3
        LXI     H,AQB
        CALL    PS
        LDA     QB
        CALL    P3
        LXI     H,AEX
        CALL    PS
        LHLD    EXPL
        CALL    P5
        LXI     H,AAN
        CALL    PS
        LHLD    ANSL
        CALL    P5
        LXI     H,AVOK
        CALL    PS
        LDA     VOK
        ORA     A
        JZ      UVO
        LXI     H,OKS
        JMP     UVP
UVO     LXI     H,DAS
UVP     CALL    PS
        LXI     H,ATXP
        CALL    PS
        LHLD    TXP
        CALL    P4
        LXI     H,ARXP
        CALL    PS
        LHLD    RXP
        CALL    P4
        LXI     H,ATXB
        CALL    PS
        LHLD    TXB
        CALL    P4
        LXI     H,ARXB
        CALL    PS
        LHLD    RXB
        CALL    P4
        LXI     H,AGOD
        CALL    PS
        LHLD    GOOD
        CALL    P4
        LXI     H,ABAD
        CALL    PS
        LHLD    BAD
        CALL    P4
        LXI     H,AMIS
        CALL    PS
        LHLD    MISS
        CALL    P4
        LXI     H,ARET
        CALL    PS
        LHLD    RETR
        CALL    P4
        LXI     H,ALB
        CALL    PS
        LDA     LB
        CALL    P2
        LXI     H,AIS
        CALL    PS
        LDA     ISB
        CALL    P2
        LXI     H,AHE
        CALL    PS
        LDA     HER
        CALL    P2
        LXI     H,AOE
        CALL    PS
        LDA     OER
        CALL    P2
        LXI     H,AEND
        CALL    PS
        LXI     H,GRN
        CALL    PS
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
CR      MVI     A,00DH
        CALL    PC
        MVI     A,00AH
        CALL    PC
        RET
CL      PUSH    B
        MVI     B,040H
CL1     MVI     A,020H
        CALL    PC
        DCR     B
        JNZ     CL1
        POP     B
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
P3      MOV     C,A
        MVI     B,000H
P3A     MOV     A,C
        CPI     064H
        JC      P3B
        SUI     064H
        MOV     C,A
        INR     B
        JMP     P3A
P3B     MOV     A,B
        ADI     '0'
        CALL    PC
        MVI     B,000H
P3C     MOV     A,C
        CPI     00AH
        JC      P3D
        SUI     00AH
        MOV     C,A
        INR     B
        JMP     P3C
P3D     MOV     A,B
        ADI     '0'
        CALL    PC
        MOV     A,C
        ADI     '0'
        CALL    PC
        RET
P5      LXI     D,2710H
        CALL    PDG
        LXI     D,03E8H
        CALL    PDG
        LXI     D,0064H
        CALL    PDG
        LXI     D,000AH
        CALL    PDG
        MOV     A,L
        ADI     '0'
        CALL    PC
        RET
PDG     MVI     B,000H
PD1     CALL    HCP
        JC      PD2
        CALL    HSB
        INR     B
        JMP     PD1
PD2     MOV     A,B
        ADI     '0'
        CALL    PC
        RET
HCP     MOV     A,H
        CMP     D
        RNZ
        MOV     A,L
        CMP     E
        RET
HSB     MOV     A,L
        SUB     E
        MOV     L,A
        MOV     A,H
        SBB     D
        MOV     H,A
        RET
SDLY    PUSH    B
        MVI     B,020H
SD1     DCR     B
        JNZ     SD1
        POP     B
        RET
DLY     PUSH    B
        MVI     B,006H
DL1     MVI     C,0D0H
DL2     DCR     C
        JNZ     DL2
        DCR     B
        JNZ     DL1
        POP     B
        RET
CLS     DB      01BH,'[','2','J',01BH,'[','H'
        DB      01BH,'[','1',';','3','2',';','4','0','m'
        DB      01BH,'[','?','2','5','l',0
NORM    DB      01BH,'[','0','m',01BH,'[','?','2','5','h',00DH,00AH,0
GRN     DB      01BH,'[','1',';','3','2','m',0
CYN     DB      01BH,'[','1',';','3','6','m',0
YEL     DB      01BH,'[','1',';','3','3','m',0
TOP     DB      '+---------------------------'
        DB      '----------------------------'
        DB      '-----------------+',0
TIT     DB      '| HWTCTL37  CONTROLLER      '
        DB      'PYTHAGOREAN  A^2 + B^2 = C^2'
        DB      '                 |',0
ROL     DB      '| Role: CONTROLLER   Phase: '
        DB      '-   Unit: -   LC: ----   Seq'
        DB      ': --             |',0
SEP     DB      '+---------------------------'
        DB      '----------------------------'
        DB      '-----------------+',0
JOB1    DB      '| Current test              '
        DB      '                            '
        DB      '                 |',0
JOB2    DB      '|      A = 000        B = 00'
        DB      '0        Expected C^2 = 0000'
        DB      '0                |',0
RES1    DB      '| Worker result             '
        DB      '                            '
        DB      '                 |',0
RES2    DB      '|      C^2 = 00000     Verif'
        DB      'y: --                       '
        DB      '                 |',0
LNK1    DB      '| Link counters             '
        DB      '                            '
        DB      '                 |',0
LNK2    DB      '|      Packets  TX:0000  RX:'
        DB      '0000        Bytes  TX:0000  '
        DB      'RX:0000          |',0
LNK3    DB      '|      Tests OK:0000   Bad:0'
        DB      '000   Miss:0000   Retry:0000'
        DB      '                 |',0
HBIO    DB      '|      HBIOS Last:00   IST:0'
        DB      '0   HA:00   OA:00           '
        DB      '                 |',0
KEYS    DB      '| Keys: Q quit    R reset   '
        DB      ' I init    A send/force    N'
        DB      'o LCD/LED I/O    |',0
BOT     DB      '+---------------------------'
        DB      '----------------------------'
        DB      '-----------------+',0
OKS     DB      'OK',0
DAS     DB      '--',0
APHS    DB      01BH,'[','3',';','2','9','H',0
AUNI    DB      01BH,'[','3',';','3','9','H',0
ALC     DB      01BH,'[','3',';','4','7','H',0
ASQ     DB      01BH,'[','3',';','4','7','H',0
AQA     DB      01BH,'[','6',';','1','2','H',0
AQB     DB      01BH,'[','6',';','2','7','H',0
AEX     DB      01BH,'[','6',';','5','3','H',0
AAN     DB      01BH,'[','8',';','1','4','H',0
AVOK    DB      01BH,'[','8',';','3','2','H',0
ATXP    DB      01BH,'[','1','2',';','2','0','H',0
ARXP    DB      01BH,'[','1','2',';','2','9','H',0
ATXB    DB      01BH,'[','1','2',';','5','1','H',0
ARXB    DB      01BH,'[','1','2',';','6','0','H',0
AGOD    DB      01BH,'[','1','3',';','1','7','H',0
ABAD    DB      01BH,'[','1','3',';','2','8','H',0
AMIS    DB      01BH,'[','1','3',';','4','0','H',0
ARET    DB      01BH,'[','1','3',';','5','3','H',0
ALB     DB      01BH,'[','1','4',';','1','9','H',0
AIS     DB      01BH,'[','1','4',';','2','8','H',0
AHE     DB      01BH,'[','1','4',';','3','6','H',0
AOE     DB      01BH,'[','1','4',';','4','4','H',0
AEND    DB      01BH,'[','1','8',';','1','H',0
DFLG    DB      0
UNI     DB      0
PHS     DB      0
ST      DB      0
SQ      DB      0
PTY     DB      0
QA      DB      0
QB      DB      0
VOK     DB      0
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
LCHR    DW      0
EXPL    DB      0
EXPH    DB      0
ANSL    DB      0
ANSH    DB      0
TXP     DW      0
TXB     DW      0
RXP     DW      0
RXB     DW      0
GOOD    DW      0
BAD     DW      0
MISS    DW      0
RETR    DW      0
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
STK     DS      256
STKE    DB      0
        END     START
