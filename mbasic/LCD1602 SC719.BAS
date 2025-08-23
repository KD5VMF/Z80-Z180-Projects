10 REM ================================================================
20 REM  LCD1602 PRIME DISPLAY — MBASIC-80 + SC719 I/O (port 0xAA)
30 REM ================================================================
40 REM  HARDWARE:
50 REM   • SC719 Digital I/O module at port 0xAA
60 REM   • Wiring: RS=P2, E=P3, D4..D7=P4..P7, RW=GND
70 REM   • Target: HD44780-based LCD1602 in 4-bit mode
80 REM
90 REM  FUNCTION:
100 REM   • Continuously generate prime numbers
110 REM   • Display each prime, right-aligned on row 0
120 REM   • Adjustable delay between updates for readability
130 REM ================================================================

30 DEFINT A-Z
40 PT=&HAA               ' SC719 output port (change if needed)
50 K=1                   ' timing scale: raise if LCD is picky
60 RV=0                  ' 0=normal bit order, 1=reversed on P4..P7
70 '---- bit masks (MBASIC = 2-char significance) ----
80 RM=&H4                ' RS on P2
90 EM=&H8                ' E  on P3
100 DM=&HF0              ' data nibble on P4..P7
110 BU=0: OUT PT,BU

120 GOSUB 3000           ' init LCD (clear once, blink off)
130 ' no header text
140 GOSUB 6000           ' start prime generator
150 END

160 '===== delays per HD44780 spec =====
170 ' short delay ~40 µs
180 FOR I=0 TO (50*K): NEXT I: RETURN
190 ' very short delay (EN pulse spacing ~1 µs)
200 FOR I=0 TO (2*K): NEXT I: RETURN
210 ' long delay ~2 ms (clear/home)
220 FOR I=0 TO (2500*K): NEXT I: RETURN

240 '===== low-level LCD write =====
250 ' write 4-bit nibble NB with RS flag FL (0=cmd,1=data)
260 IF FL THEN BU=BU OR RM ELSE BU=BU AND (255-RM)
270 NB=NB AND &HF
280 IF RV=0 THEN VV=NB*16 ELSE VV=((NB AND 1)*128)+((NB AND 2)*32)+((NB AND 4)*8)+((NB AND 8)*2)
290 BU=(BU AND (255-DM)) OR VV
300 OUT PT,BU: GOSUB 200          ' send nibble low
310 BU=BU OR EM: OUT PT,BU: GOSUB 200  ' pulse E high
320 BU=BU AND (255-EM): OUT PT,BU: GOSUB 200 ' pulse E low
330 RETURN

340 ' write full byte BY (hi nibble first)
350 NB=(BY AND &HF0)\16: GOSUB 250
360 NB=BY AND &HF: GOSUB 250
370 RETURN

380 ' command write
390 FL=0: GOSUB 340
400 IF BY=&H1 OR BY=&H2 THEN GOSUB 220 ELSE GOSUB 180
410 RETURN

420 ' data write
430 FL=1: GOSUB 340: GOSUB 180: RETURN

440 '===== helpers =====
450 ' set cursor to column C0 (0..15), row R0 (0 or 1)
460 IF R0=0 THEN BA=&H0 ELSE BA=&H40
470 BY=&H80+BA+C0: GOSUB 380: RETURN

480 ' print string S$ at (C,R)
490 C0=C: R0=R: GOSUB 450
500 FOR J=1 TO LEN(S$): BY=ASC(MID$(S$,J,1)): GOSUB 420: NEXT J
510 RETURN

3000 '===== LCD init (4-bit mode) =====
3010 GOSUB 220
3020 FL=0: NB=&H3: GOSUB 250: GOSUB 220
3030 NB=&H3: GOSUB 250: GOSUB 220
3040 NB=&H3: GOSUB 250: GOSUB 220
3050 NB=&H2: GOSUB 250: GOSUB 180
3060 BY=&H28: GOSUB 380        ' function set: 4-bit, 2 lines, 5x8
3070 BY=&H8: GOSUB 380         ' display OFF
3080 BY=&H1: GOSUB 380         ' clear once
3090 BY=&H6: GOSUB 380         ' entry mode (cursor right)
3100 BY=&HC: GOSUB 380         ' display ON, cursor OFF, blink OFF
3110 RETURN

5000 '===== right-align number into 10 chars -> PAD$ =====
5010 S$=STR$(N): IF LEFT$(S$,1)=" " THEN S$=MID$(S$,2)
5020 PAD$="": FOR Z=1 TO (10-LEN(S$)): PAD$=PAD$+" ": NEXT Z
5030 PAD$=PAD$+S$: RETURN

6000 '===== prime loop =====
6010 PN=2
6020 IF PN<2 THEN PN=2
6030 GOSUB 7000: IF IS THEN GOSUB 6100
6040 IF PN=2 THEN PN=3 ELSE PN=PN+2
6050 GOTO 6030

6100 ' print prime on line 0
6110 N=PN: GOSUB 5000: C=6: R=0: S$=PAD$: GOSUB 480
6120 FOR T=1 TO 1000: NEXT T   ' adjust delay for human viewing
6130 RETURN

7000 '===== primality test =====
7010 IF PN<2 THEN IS=0: RETURN
7020 IF PN=2 OR PN=3 OR PN=5 THEN IS=1: RETURN
7030 IF (PN AND 1)=0 THEN IS=0: RETURN    ' even
7040 IF PN MOD 3=0 OR PN MOD 5=0 THEN IS=0: RETURN
7050 LM=INT(SQR(PN))
7060 IS=1
7070 FOR DV=7 TO LM STEP 2
7080 IF PN MOD DV=0 THEN IS=0: RETURN
7090 NEXT DV
7100 RETURN
