10 REM ================================================================
20 REM  LCD1602 PRIME GENERATOR  —  MBASIC-80 / SC719 I/O (0xAA)
30 REM  Author: 78 Hamster & ChatGPT
40 REM  Hardware: SC719 Digital I/O card driving HD44780 LCD in 4-bit mode
50 REM  Purpose: Continuously generate and display prime numbers on LCD1602
60 REM ================================================================
70 REM  ABOUT:
80 REM   • Connect SC719 port 0xAA: RS=P2, E=P3, D4..D7=P4..P7, RW=GND.
90 REM   • Program finds prime numbers and shows them right-aligned on row 0.
100 REM   • LCD driver is bit-banged in 4-bit mode with precise delays.
110 REM   • The prime generator uses trial division up to √N.
120 REM   • Adjustable delay loop allows human-readable pace.
130 REM ================================================================

140 DEFINT A-Z              ' default all variables to integer
150 PT=&HAA                 ' SC719 base output port (change if needed)
160 K=1                     ' timing scale: raise if LCD is picky
170 RV=0                    ' 0=normal bit order, 1=reversed nibble wiring
180 '---- bit masks (only 2-char significance in MBASIC) ----
190 RM=&H4                  ' RS flag bit (P2)
200 EM=&H8                  ' E  flag bit (P3)
210 DM=&HF0                 ' data nibble mask (P4..P7)
220 BU=0: OUT PT,BU         ' clear output latch

230 GOSUB 3000              ' initialize LCD (4-bit mode, clear, blink off)
240 GOSUB 6000              ' start prime generator
250 END

260 '========================================================
270 '   DELAYS (tuned for HD44780 LCD controller timings)
280 '========================================================
290 ' short delay ~40 µs
300 FOR I=0 TO (50*K): NEXT I: RETURN
310 ' very short delay ~1 µs (EN pulse spacing)
320 FOR I=0 TO (2*K): NEXT I: RETURN
330 ' long delay ~2 ms (clear/home)
340 FOR I=0 TO (2500*K): NEXT I: RETURN
350 RETURN

360 '========================================================
370 '   LCD WRITE ROUTINES (low-level 4-bit transfers)
380 '========================================================
390 ' write 4-bit nibble NB with RS flag FL (0=cmd,1=data)
400 IF FL THEN BU=BU OR RM ELSE BU=BU AND (255-RM)
410 NB=NB AND &HF
420 IF RV=0 THEN VV=NB*16 ELSE VV=((NB AND 1)*128)+((NB AND 2)*32)+((NB AND 4)*8)+((NB AND 8)*2)
430 BU=(BU AND (255-DM)) OR VV
440 OUT PT,BU: GOSUB 320
450 BU=BU OR EM: OUT PT,BU: GOSUB 320
460 BU=BU AND (255-EM): OUT PT,BU: GOSUB 320
470 RETURN

480 ' write full byte BY (hi nibble first, then lo nibble)
490 NB=(BY AND &HF0)\16: GOSUB 390
500 NB=BY AND &HF: GOSUB 390
510 RETURN

520 ' send command byte
530 FL=0: GOSUB 480
540 IF BY=&H1 OR BY=&H2 THEN GOSUB 340 ELSE GOSUB 300
550 RETURN

560 ' send data byte
570 FL=1: GOSUB 480: GOSUB 300: RETURN

580 '========================================================
590 '   HELPER ROUTINES
600 '========================================================
610 ' set cursor to (column C0, row R0)
620 IF R0=0 THEN BA=&H0 ELSE BA=&H40
630 BY=&H80+BA+C0: GOSUB 530: RETURN

640 ' print string S$ at (C,R)
650 C0=C: R0=R: GOSUB 610
660 FOR J=1 TO LEN(S$): BY=ASC(MID$(S$,J,1)): GOSUB 570: NEXT J
670 RETURN

680 '========================================================
690 '   LCD INITIALIZATION (4-bit mode, per HD44780 spec)
700 '========================================================
710 GOSUB 340
720 FL=0: NB=&H3: GOSUB 390: GOSUB 340
730 NB=&H3: GOSUB 390: GOSUB 340
740 NB=&H3: GOSUB 390: GOSUB 340
750 NB=&H2: GOSUB 390: GOSUB 300
760 BY=&H28: GOSUB 530        ' function set: 4-bit, 2 lines, 5x8 font
770 BY=&H8: GOSUB 530         ' display OFF
780 BY=&H1: GOSUB 530         ' clear display
790 BY=&H6: GOSUB 530         ' entry mode (cursor right)
800 BY=&HC: GOSUB 530         ' display ON, cursor OFF, blink OFF
810 RETURN

820 '========================================================
830 '   NUMBER FORMATTING (right-align primes in 10 cols)
840 '========================================================
850 S$=STR$(N): IF LEFT$(S$,1)=" " THEN S$=MID$(S$,2)
860 PAD$="": FOR Z=1 TO (10-LEN(S$)): PAD$=PAD$+" ": NEXT Z
870 PAD$=PAD$+S$: RETURN

880 '========================================================
890 '   PRIME GENERATOR LOOP
900 '========================================================
910 PN=2
920 IF PN<2 THEN PN=2
930 GOSUB 1000: IF IS THEN GOSUB 1100
940 IF PN=2 THEN PN=3 ELSE PN=PN+2
950 GOTO 930

960 ' print prime to LCD line 0
970 N=PN: GOSUB 850: C=6: R=0: S$=PAD$: GOSUB 640
980 FOR T=1 TO 2000: NEXT T    ' adjustable viewing delay
990 RETURN

1000 '========================================================
1010 '   PRIMALITY TEST (trial division up to √N)
1020 '========================================================
1030 IF PN<2 THEN IS=0: RETURN
1040 IF PN=2 OR PN=3 OR PN=5 THEN IS=1: RETURN
1050 IF (PN AND 1)=0 THEN IS=0: RETURN       ' even >2
1060 IF PN MOD 3=0 OR PN MOD 5=0 THEN IS=0: RETURN
1070 LM=INT(SQR(PN))
1080 IS=1
1090 FOR DV=7 TO LM STEP 2
1100   IF PN MOD DV=0 THEN IS=0: RETURN
1110 NEXT DV
1120 RETURN
