        ORG     0100H
        JMP     START
BDOS    EQU     0005H
DRATE   EQU     004H
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
        STA     ACNT
        STA     ACNT+1
        STA     GCNT
        STA     GCNT+1
        STA     ANCNT
        STA     ANCNT+1
        STA     MCNT
        STA     MCNT+1
        STA     LASTB
        STA     LAST0
        STA     LAST1
        STA     LAST2
        STA     LAST3
        STA     LAST4
        STA     LAST5
        STA     LAST6
        STA     LAST7
        CALL    RMAXS
        MVI     A,0C8H
        STA     AGE
        LXI     H,CLS
        CALL    PSTR
        LXI     H,HIDE
        CALL    PSTR
        CALL    INIHBI
        CALL    FLUSH
        CALL    DRAW
MAIN    CALL    PSER
        CALL    CHKEY
        LDA     NEWFLG
        ORA     A
        JZ      CKAGE
        XRA     A
        STA     NEWFLG
        CALL    DRAW
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
        MVI     A,001H
        STA     LOST
        CALL    DRAW
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
        CPI     052H
        JZ      RKEY
        CPI     072H
        JZ      RKEY
        CPI     030H
        JC      NOKEY
        CPI     038H
        JNC     NOKEY
        SUI     030H
        STA     SELUNI
        CALL    RSETC
        CALL    INIHBI
        CALL    FLUSH
        CALL    DRAW
        RET
RKEY    CALL    RMAXS
        CALL    DRAW
        RET
NOKEY   RET
EXIT    LXI     H,SHOW
        CALL    PSTR
        CALL    PCRLF
        JMP     0000H
RSETC   XRA     A
        STA     BYCNT
        STA     BYCNT+1
        STA     ACNT
        STA     ACNT+1
        STA     GCNT
        STA     GCNT+1
        STA     ANCNT
        STA     ANCNT+1
        STA     MCNT
        STA     MCNT+1
        STA     LASTB
        STA     LAST0
        STA     LAST1
        STA     LAST2
        STA     LAST3
        STA     LAST4
        STA     LAST5
        STA     LAST6
        STA     LAST7
        CALL    RMAXS
        XRA     A
        STA     PSTATE
        STA     PINDEX
        STA     PSUM
        STA     NEWFLG
        STA     RAWFLG
        STA     LOST
        MVI     A,0C8H
        STA     AGE
        RET
RMAXS   XRA     A
        STA     AXP
        STA     AXP+1
        STA     AXN
        STA     AXN+1
        STA     AYP
        STA     AYP+1
        STA     AYN
        STA     AYN+1
        STA     AZP
        STA     AZP+1
        STA     AZN
        STA     AZN+1
        STA     MXP
        STA     MXP+1
        STA     MXN
        STA     MXN+1
        STA     MYP
        STA     MYP+1
        STA     MYN
        STA     MYN+1
        STA     MZP
        STA     MZP+1
        STA     MZN
        STA     MZN+1
        RET
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
        LDA     LAST4
        STA     LAST3
        LDA     LAST5
        STA     LAST4
        LDA     LAST6
        STA     LAST5
        LDA     LAST7
        STA     LAST6
        LDA     LASTB
        STA     LAST7
        RET
INCBYT  LHLD    BYCNT
        INX     H
        SHLD    BYCNT
        RET
INCAC   LHLD    ACNT
        INX     H
        SHLD    ACNT
        RET
INCGY   LHLD    GCNT
        INX     H
        SHLD    GCNT
        RET
INCMG   LHLD    MCNT
        INX     H
        SHLD    MCNT
        RET
INCAN   LHLD    ANCNT
        INX     H
        SHLD    ANCNT
        RET
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
        CPI     051H
        JZ      PACC
        CPI     052H
        JZ      PGYR
        CPI     053H
        JZ      PANG
        CPI     054H
        JZ      PMAG
        JMP     PBDON
PACC    CALL    PARAC
        CALL    INCAC
        JMP     PBDON
PGYR    CALL    PARGY
        CALL    INCGY
        JMP     PBDON
PANG    CALL    PARAN
        CALL    INCAN
        JMP     PBDON
PMAG    CALL    PARMG
        CALL    INCMG
        JMP     PBDON
PBDON   XRA     A
        STA     PSTATE
        RET
PBAD    XRA     A
        STA     PSTATE
        RET
PARAC   LDA     FRAME+2
        STA     AXRAW
        LDA     FRAME+3
        STA     AXRAW+1
        LDA     FRAME+4
        STA     AYRAW
        LDA     FRAME+5
        STA     AYRAW+1
        LDA     FRAME+6
        STA     AZRAW
        LDA     FRAME+7
        STA     AZRAW+1
        CALL    CHKAC
        RET
PARGY   LDA     FRAME+2
        STA     GXRAW
        LDA     FRAME+3
        STA     GXRAW+1
        LDA     FRAME+4
        STA     GYRAW
        LDA     FRAME+5
        STA     GYRAW+1
        LDA     FRAME+6
        STA     GZRAW
        LDA     FRAME+7
        STA     GZRAW+1
        RET
PARMG   LDA     FRAME+2
        STA     MXRAW
        LDA     FRAME+3
        STA     MXRAW+1
        LDA     FRAME+4
        STA     MYRAW
        LDA     FRAME+5
        STA     MYRAW+1
        LDA     FRAME+6
        STA     MZRAW
        LDA     FRAME+7
        STA     MZRAW+1
        CALL    CHKMG
        RET
PARAN   LDA     FRAME+2
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
        SHLD    YRAW
        CALL    RAWDG
        STA     YDEG
        LDA     SIGNC
        STA     YSIGN
        LDA     SIGNC
        CPI     02DH
        JZ      YNEG
        LDA     YDEG
        MOV     L,A
        MVI     H,000H
        SHLD    HDEG
        JMP     PGOOD
YNEG    LDA     YDEG
        ORA     A
        JZ      YZERO
        MOV     E,A
        MVI     D,000H
        LXI     H,0168H
        CALL    SUBDE
        SHLD    HDEG
        JMP     PGOOD
YZERO   LXI     H,0000H
        SHLD    HDEG
PGOOD   MVI     A,0FFH
        STA     AGE
        XRA     A
        STA     LOST
        LDA     DISPC
        INR     A
        CPI     DRATE
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
CHKAC   LHLD    AXRAW
        CALL    ABSHL
        LDA     SIGNC
        CPI     02DH
        JZ      CAXN
        XCHG
        LHLD    AXP
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CAY0
        SHLD    AXP
        JMP     CAY0
CAXN    XCHG
        LHLD    AXN
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CAY0
        SHLD    AXN
CAY0    LHLD    AYRAW
        CALL    ABSHL
        LDA     SIGNC
        CPI     02DH
        JZ      CAYN
        XCHG
        LHLD    AYP
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CAZ0
        SHLD    AYP
        JMP     CAZ0
CAYN    XCHG
        LHLD    AYN
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CAZ0
        SHLD    AYN
CAZ0    LHLD    AZRAW
        CALL    ABSHL
        LDA     SIGNC
        CPI     02DH
        JZ      CAZN
        XCHG
        LHLD    AZP
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CADON
        SHLD    AZP
        JMP     CADON
CAZN    XCHG
        LHLD    AZN
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CADON
        SHLD    AZN
CADON   RET
CHKMG   LHLD    MXRAW
        CALL    ABSHL
        LDA     SIGNC
        CPI     02DH
        JZ      CMXN
        XCHG
        LHLD    MXP
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CMY0
        SHLD    MXP
        JMP     CMY0
CMXN    XCHG
        LHLD    MXN
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CMY0
        SHLD    MXN
CMY0    LHLD    MYRAW
        CALL    ABSHL
        LDA     SIGNC
        CPI     02DH
        JZ      CMYN
        XCHG
        LHLD    MYP
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CMZ0
        SHLD    MYP
        JMP     CMZ0
CMYN    XCHG
        LHLD    MYN
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CMZ0
        SHLD    MYN
CMZ0    LHLD    MZRAW
        CALL    ABSHL
        LDA     SIGNC
        CPI     02DH
        JZ      CMZN
        XCHG
        LHLD    MZP
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CMDON
        SHLD    MZP
        JMP     CMDON
CMZN    XCHG
        LHLD    MZN
        MOV     B,H
        MOV     C,L
        XCHG
        CALL    CMPBC
        JC      CMDON
        SHLD    MZN
CMDON   RET
ABSHL   MOV     A,H
        ANI     080H
        JZ      ABPOS
        MVI     A,02DH
        STA     SIGNC
        MOV     A,L
        CMA
        MOV     L,A
        MOV     A,H
        CMA
        MOV     H,A
        INX     H
        RET
ABPOS   MVI     A,02BH
        STA     SIGNC
        RET
DRAW    LXI     H,HOME
        CALL    PSTR
        LXI     H,CCYN
        CALL    PSTR
        LXI     H,LTTL
        CALL    PSTR
        LXI     H,CRES
        CALL    PSTR
        CALL    PCRLF
        LXI     H,CBLU
        CALL    PSTR
        LXI     H,LDASH
        CALL    PSTR
        LXI     H,CRES
        CALL    PSTR
        CALL    PCRLF
        LXI     H,CGRE
        CALL    PSTR
        LXI     H,LSER
        CALL    PSTR
        LDA     SELUNI
        ADI     030H
        CALL    PCH
        LXI     H,L960
        CALL    PSTR
        LDA     LOST
        ORA     A
        JZ      DOK
        LXI     H,CRED
        CALL    PSTR
        LXI     H,LNOD
        CALL    PSTR
        JMP     D1
DOK     LXI     H,CGRE
        CALL    PSTR
        LXI     H,LOK
        CALL    PSTR
D1      LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CYEL
        CALL    PSTR
        LXI     H,LHDG
        CALL    PSTR
        LHLD    HDEG
        CALL    P3D
        LXI     H,LDIR
        CALL    PSTR
        LHLD    HDEG
        CALL    GETDIR
        MOV     A,D
        CALL    PCH
        MOV     A,E
        CALL    PCH
        LXI     H,LYAW
        CALL    PSTR
        LDA     YSIGN
        CALL    PCH
        LDA     YDEG
        MOV     L,A
        MVI     H,000H
        CALL    P3D
        LXI     H,LDEG
        CALL    PSTR
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CYEL
        CALL    PSTR
        LXI     H,LPIT
        CALL    PSTR
        LDA     PSIGN
        CALL    PCH
        LDA     PDEG
        MOV     L,A
        MVI     H,000H
        CALL    P3D
        LXI     H,LDEG
        CALL    PSTR
        LXI     H,LROL
        CALL    PSTR
        LDA     RSIGN
        CALL    PCH
        LDA     RDEG
        MOV     L,A
        MVI     H,000H
        CALL    P3D
        LXI     H,LDEG
        CALL    PSTR
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        CALL    PCRLF
        LXI     H,CGRE
        CALL    PSTR
        LXI     H,LACC
        CALL    PSTR
        LHLD    AXRAW
        CALL    PS16
        LXI     H,LACCY
        CALL    PSTR
        LHLD    AYRAW
        CALL    PS16
        LXI     H,LACCZ
        CALL    PSTR
        LHLD    AZRAW
        CALL    PS16
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CMAG
        CALL    PSTR
        LXI     H,LGYR
        CALL    PSTR
        LHLD    GXRAW
        CALL    PS16
        LXI     H,LACCY
        CALL    PSTR
        LHLD    GYRAW
        CALL    PS16
        LXI     H,LACCZ
        CALL    PSTR
        LHLD    GZRAW
        CALL    PS16
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CCYN
        CALL    PSTR
        LXI     H,LMAG
        CALL    PSTR
        LHLD    MXRAW
        CALL    PS16
        LXI     H,LACCY
        CALL    PSTR
        LHLD    MYRAW
        CALL    PS16
        LXI     H,LACCZ
        CALL    PSTR
        LHLD    MZRAW
        CALL    PS16
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        CALL    PCRLF
        LXI     H,CYEL
        CALL    PSTR
        LXI     H,LMAXGP
        CALL    PSTR
        LXI     H,LXTXT
        CALL    PSTR
        LHLD    AXP
        CALL    PGVAL
        LXI     H,LYTXT
        CALL    PSTR
        LHLD    AYP
        CALL    PGVAL
        LXI     H,LZTXT
        CALL    PSTR
        LHLD    AZP
        CALL    PGVAL
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CYEL
        CALL    PSTR
        LXI     H,LMAXGN
        CALL    PSTR
        LXI     H,LXTXT
        CALL    PSTR
        LHLD    AXN
        CALL    PGVAL
        LXI     H,LYTXT
        CALL    PSTR
        LHLD    AYN
        CALL    PGVAL
        LXI     H,LZTXT
        CALL    PSTR
        LHLD    AZN
        CALL    PGVAL
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CCYN
        CALL    PSTR
        LXI     H,LMAXMP
        CALL    PSTR
        LXI     H,LXTXT
        CALL    PSTR
        LHLD    MXP
        CALL    P5D
        LXI     H,LYTXT
        CALL    PSTR
        LHLD    MYP
        CALL    P5D
        LXI     H,LZTXT
        CALL    PSTR
        LHLD    MZP
        CALL    P5D
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CCYN
        CALL    PSTR
        LXI     H,LMAXMN
        CALL    PSTR
        LXI     H,LXTXT
        CALL    PSTR
        LHLD    MXN
        CALL    P5D
        LXI     H,LYTXT
        CALL    PSTR
        LHLD    MYN
        CALL    P5D
        LXI     H,LZTXT
        CALL    PSTR
        LHLD    MZN
        CALL    P5D
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        CALL    PCRLF
        LXI     H,CBLU
        CALL    PSTR
        LXI     H,LPKT
        CALL    PSTR
        LHLD    ANCNT
        CALL    P4H
        LXI     H,LACC2
        CALL    PSTR
        LHLD    ACNT
        CALL    P4H
        LXI     H,LGYR2
        CALL    PSTR
        LHLD    GCNT
        CALL    P4H
        LXI     H,LMAG2
        CALL    PSTR
        LHLD    MCNT
        CALL    P4H
        LXI     H,LBYT
        CALL    PSTR
        LHLD    BYCNT
        CALL    P4H
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,CBLU
        CALL    PSTR
        LXI     H,LLST
        CALL    PSTR
        LDA     LAST0
        CALL    P2H
        CALL    PSPC
        LDA     LAST1
        CALL    P2H
        CALL    PSPC
        LDA     LAST2
        CALL    P2H
        CALL    PSPC
        LDA     LAST3
        CALL    P2H
        CALL    PSPC
        LDA     LAST4
        CALL    P2H
        CALL    PSPC
        LDA     LAST5
        CALL    P2H
        CALL    PSPC
        LDA     LAST6
        CALL    P2H
        CALL    PSPC
        LDA     LAST7
        CALL    P2H
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        CALL    PCRLF
        LXI     H,CGRE
        CALL    PSTR
        LXI     H,LKEY
        CALL    PSTR
        LXI     H,CRES
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
        LXI     H,LRAW
        CALL    PSTR
        CALL    PCLR
        CALL    PCRLF
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
PSTR    MOV     A,M
        ORA     A
        RZ
        CALL    PCH
        INX     H
        JMP     PSTR
PCH     PUSH    PSW
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
PCRLF   MVI     A,00DH
        CALL    PCH
        MVI     A,00AH
        CALL    PCH
        RET
PSPC    MVI     A,020H
        CALL    PCH
        RET
PCLR    PUSH    B
        MVI     B,018H
PCL1    MVI     A,020H
        CALL    PCH
        DCR     B
        JNZ     PCL1
        POP     B
        RET
PS16    MOV     A,H
        ANI     080H
        JZ      PS16P
        MVI     A,02DH
        CALL    PCH
        MOV     A,L
        CMA
        MOV     L,A
        MOV     A,H
        CMA
        MOV     H,A
        INX     H
        CALL    P5D
        RET
PS16P   MVI     A,02BH
        CALL    PCH
        CALL    P5D
        RET
P5D     LXI     B,2710H
        CALL    PDIG
        LXI     B,03E8H
        CALL    PDIG
        LXI     B,0064H
        CALL    PDIG
        LXI     B,000AH
        CALL    PDIG
        MOV     A,L
        ADI     030H
        CALL    PCH
        RET
P3D     LXI     B,0064H
        CALL    PDIG
        LXI     B,000AH
        CALL    PDIG
        MOV     A,L
        ADI     030H
        CALL    PCH
        RET
PDIG    MVI     D,000H
PDIG1   CALL    CMPBC
        JC      PDIG2
        CALL    SUBBC
        INR     D
        JMP     PDIG1
PDIG2   MOV     A,D
        ADI     030H
        CALL    PCH
        RET
PGVAL   CALL    DIV20
        MVI     D,000H
PGI1    LXI     B,0064H
        CALL    CMPBC
        JC      PGI2
        CALL    SUBBC
        INR     D
        JMP     PGI1
PGI2    MOV     A,D
        CALL    P2A
        MVI     A,02EH
        CALL    PCH
        MOV     A,L
        CALL    P2A
        MVI     A,067H
        CALL    PCH
        RET
DIV20   LXI     D,0000H
DV20A   LXI     B,0014H
        CALL    CMPBC
        JC      DV20D
        CALL    SUBBC
        INX     D
        JMP     DV20A
DV20D   XCHG
        RET
P2A     MOV     D,A
        MVI     C,000H
P2A1    MOV     A,D
        CPI     00AH
        JC      P2A2
        SUI     00AH
        MOV     D,A
        INR     C
        JMP     P2A1
P2A2    MOV     A,C
        ADI     030H
        CALL    PCH
        MOV     A,D
        ADI     030H
        CALL    PCH
        RET
P4H     MOV     A,H
        CALL    P2H
        MOV     A,L
        CALL    P2H
        RET
P2H     PUSH    PSW
        RRC
        RRC
        RRC
        RRC
        ANI     00FH
        CALL    HXCH
        CALL    PCH
        POP     PSW
        ANI     00FH
        CALL    HXCH
        CALL    PCH
        RET
HXCH    CPI     00AH
        JC      HXNUM
        ADI     037H
        RET
HXNUM   ADI     030H
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
SDLY    LXI     H,0800H
SDLY1   DCX     H
        MOV     A,H
        ORA     L
        JNZ     SDLY1
        RET
CLS     DB      01BH,05BH,032H,04AH,01BH,05BH,048H,000H
HOME    DB      01BH,05BH,048H,000H
HIDE    DB      01BH,05BH,03FH,032H,035H,06CH,000H
SHOW    DB      01BH,05BH,03FH,032H,035H,068H,000H
CRES    DB      01BH,05BH,030H,06DH,000H
CBLU    DB      01BH,05BH,031H,03BH,033H,034H,06DH,000H
CCYN    DB      01BH,05BH,031H,03BH,033H,036H,06DH,000H
CGRE    DB      01BH,05BH,031H,03BH,033H,032H,06DH,000H
CYEL    DB      01BH,05BH,031H,03BH,033H,033H,06DH,000H
CRED    DB      01BH,05BH,031H,03BH,033H,031H,06DH,000H
CMAG    DB      01BH,05BH,031H,03BH,033H,035H,06DH,000H
LTTL  DB      04BH,044H,035H,056H,04DH,046H,020H,048H
        DB      057H,054H,039H,030H,035H,044H,020H,05AH
        DB      031H,038H,030H,020H,054H,045H,052H,04DH
        DB      049H,04EH,041H,04CH,020H,049H,04DH,055H
        DB      020H,04DH,041H,058H,000H
LDASH   DB      02DH,02DH,02DH,02DH,02DH,02DH,02DH,02DH
        DB      02DH,02DH,02DH,02DH,02DH,02DH,02DH,02DH
        DB      02DH,02DH,02DH,02DH,02DH,02DH,02DH,02DH
        DB      02DH,02DH,02DH,02DH,02DH,02DH,02DH,02DH
        DB      02DH,02DH,02DH,02DH,000H
LSER    DB      053H,065H,072H,069H,061H,06CH,03AH,020H
        DB      048H,042H,049H,04FH,053H,020H,075H,06EH
        DB      069H,074H,020H,000H
L960    DB      020H,020H,039H,036H,030H,030H,020H,038H
        DB      04EH,031H,020H,020H,020H,053H,074H,061H
        DB      074H,075H,073H,03AH,020H,000H
LOK     DB      04FH,04BH,020H,000H
LNOD    DB      04EH,04FH,020H,041H,04EH,047H,04CH,045H
        DB      020H,000H
LHDG    DB      048H,065H,061H,064H,069H,06EH,067H,03AH
        DB      020H,000H
LDIR    DB      020H,020H,020H,044H,069H,072H,03AH,020H
        DB      000H
LYAW    DB      020H,020H,020H,059H,061H,077H,03AH,020H
        DB      000H
LDEG    DB      020H,064H,065H,067H,000H
LPIT    DB      050H,069H,074H,063H,068H,03AH,020H,020H
        DB      020H,000H
LROL    DB      020H,020H,020H,052H,06FH,06CH,06CH,03AH
        DB      020H,000H
LACC    DB      041H,063H,063H,065H,06CH,020H,052H,041H
        DB      057H,03AH,020H,058H,020H,000H
LACCY   DB      020H,020H,059H,020H,000H
LACCZ   DB      020H,020H,05AH,020H,000H
LGYR    DB      047H,079H,072H,06FH,020H,020H,052H,041H
        DB      057H,03AH,020H,058H,020H,000H
LMAG  DB      04DH,061H,067H,020H,020H,020H,052H,041H
        DB      057H,03AH,020H,058H,020H,000H
LMAXGP DB      04DH,061H,078H,020H,047H,020H,02BH,020H
        DB      064H,069H,072H,03AH,020H,000H
LMAXGN DB      04DH,061H,078H,020H,047H,020H,02DH,020H
        DB      064H,069H,072H,03AH,020H,000H
LMAXMP DB      04DH,061H,078H,020H,04DH,061H,067H,020H
        DB      02BH,020H,072H,061H,077H,03AH,020H,000H
LMAXMN DB      04DH,061H,078H,020H,04DH,061H,067H,020H
        DB      02DH,020H,072H,061H,077H,03AH,020H,000H
LXTXT  DB      058H,020H,000H
LYTXT  DB      020H,020H,059H,020H,000H
LZTXT  DB      020H,020H,05AH,020H,000H
LPKT    DB      050H,061H,063H,06BH,065H,074H,073H,03AH
        DB      020H,041H,04EH,047H,020H,000H
LACC2   DB      020H,020H,041H,043H,043H,020H,000H
LGYR2   DB      020H,020H,047H,059H,052H,020H,000H
LMAG2   DB      020H,020H,04DH,041H,047H,020H,000H
LBYT    DB      020H,020H,042H,059H,054H,045H,053H,020H
        DB      000H
LLST    DB      04CH,061H,073H,074H,020H,062H,079H,074H
        DB      065H,073H,03AH,020H,000H
LKEY  DB      04BH,065H,079H,073H,03AH,020H,051H,020H
        DB      065H,078H,069H,074H,020H,020H,020H,052H
        DB      020H,072H,065H,073H,065H,074H,020H,06DH
        DB      061H,078H,020H,020H,020H,030H,02DH,037H
        DB      020H,073H,065H,06CH,065H,063H,074H,020H
        DB      048H,042H,049H,04FH,053H,020H,073H,065H
        DB      072H,069H,061H,06CH,020H,075H,06EH,069H
        DB      074H,000H
LRAW  DB      04EH,06FH,020H,04CH,043H,044H,020H,06FH
        DB      072H,020H,04CH,045H,044H,020H,049H,02FH
        DB      04FH,02EH,020H,054H,065H,072H,06DH,069H
        DB      06EH,061H,06CH,02DH,06FH,06EH,06CH,079H
        DB      020H,064H,061H,073H,068H,062H,06FH,061H
        DB      072H,064H,02EH,020H,04DH,061H,078H,065H
        DB      073H,020H,068H,06FH,06CH,064H,020H,075H
        DB      06EH,074H,069H,06CH,020H,052H,020H,072H
        DB      065H,073H,065H,074H,02EH,000H
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
LAST4   DB      00H
LAST5   DB      00H
LAST6   DB      00H
LAST7   DB      00H
BYCNT   DW      0000H
ACNT    DW      0000H
GCNT    DW      0000H
ANCNT   DW      0000H
MCNT    DW      0000H
AXP     DW      0000H
AXN     DW      0000H
AYP     DW      0000H
AYN     DW      0000H
AZP     DW      0000H
AZN     DW      0000H
MXP     DW      0000H
MXN     DW      0000H
MYP     DW      0000H
MYN     DW      0000H
MZP     DW      0000H
MZN     DW      0000H
HDEG    DW      0000H
YDEG    DB      00H
PDEG    DB      00H
RDEG    DB      00H
PSIGN   DB      02BH
RSIGN   DB      02BH
YSIGN   DB      02BH
SIGNC   DB      02BH
YRAW    DW      0000H
AXRAW   DW      0000H
AYRAW   DW      0000H
AZRAW   DW      0000H
GXRAW   DW      0000H
GYRAW   DW      0000H
GZRAW   DW      0000H
MXRAW   DW      0000H
MYRAW   DW      0000H
MZRAW   DW      0000H
STACK   DS      128
STACKE
        END     START
