10 REM === LCD1602 via SC719 (0xDA) b COUNTER, NO LEADING ZEROS, STABLE ===
20 REM SC700 / Z180 with SC719 I/O: RS=P2, E=P3, D4..D7=P4..P7, RW=GND
30 DEFINT A-Z
40 PT=&H32               ' Set your SC719 IO Port here
50 K=0                   ' 0 = fastest; if LCD glitches, try K=1
60 RV=0                  ' 0=normal nibble order, 1=reversed on P4..P7
70 '---- bit masks ----
80 RM=&H4                ' RS on P2
90 EM=&H8                ' E  on P3
100 DM=&HF0              ' data nibble on P4..P7
110 BU=0: OUT PT,BU
120 GOSUB 3000           ' init LCD
130 '---- digits array init ----
135 DIM D(10)
136 FOR I=1 TO 10: D(I)=0: NEXT I
140 R=0: C=6
145 GOSUB 5300           ' build right-aligned "0"
150 GOSUB 450            ' paint once
160 GOTO 6000
180 '===== delays per HD44780 spec =====
190 FOR I=0 TO (50*K): NEXT I: RETURN
200 FOR I=0 TO (2*K): NEXT I: RETURN
210 FOR I=0 TO (2500*K): NEXT I: RETURN
220 RETURN
230 '===== low-level LCD write: nibble in NB; FL=0 cmd / 1 data =====
240 IF FL THEN BU=BU OR RM ELSE BU=BU AND (255-RM)
250 NB=NB AND &HF
260 IF RV=0 THEN VV=NB*16 ELSE VV=((NB AND 1)*128)+((NB AND 2)*32)+((NB AND 4)*8
)+((NB AND 8)*2)
270 BU=(BU AND (255-DM)) OR VV
280 OUT PT,BU: GOSUB 200
290 BU=BU OR EM: OUT PT,BU: GOSUB 200
300 BU=BU AND (255-EM): OUT PT,BU: GOSUB 200
310 RETURN
320 '===== send full byte in BY =====
330 NB=INT((BY AND &HF0)/16): GOSUB 230
340 NB=BY AND &HF: GOSUB 230
350 RETURN
360 '===== write command byte in BY =====
370 FL=0: GOSUB 320
380 IF BY=&H1 OR BY=&H2 THEN GOSUB 210 ELSE GOSUB 190
390 RETURN
400 '===== write data byte in BY =====
410 FL=1: GOSUB 320: GOSUB 190: RETURN
420 '===== helpers: set DDRAM addr & print S$ at (R,C) =====
430 IF R0=0 THEN BA=&H0 ELSE BA=&H40
440 BY=&H80+BA+C0: GOSUB 360: RETURN
450 C0=C: R0=R: GOSUB 430
460 FOR J=1 TO LEN(S$): BY=ASC(MID$(S$,J,1)): GOSUB 400: NEXT J
470 RETURN
3000 '===== LCD init (4-bit, 2-line, 5x8) =====
3010 GOSUB 210
3020 FL=0: NB=&H3: GOSUB 230: GOSUB 210
3030 NB=&H3: GOSUB 230: GOSUB 210
3040 NB=&H3: GOSUB 230: GOSUB 210
3050 NB=&H2: GOSUB 230: GOSUB 190
3060 BY=&H28: GOSUB 360       ' 4-bit, 2-line, 5x8
3070 BY=&H8: GOSUB 360       ' display off
3080 BY=&H1: GOSUB 360       ' clear
3090 BY=&H6: GOSUB 360       ' entry: inc, no shift
3100 BY=&HC: GOSUB 360       ' display on, cursor off, blink off
3110 RETURN
5000 '===== increment D(1..10) as BCD (rightmost first) =====
5010 FOR P=10 TO 1 STEP -1
5020   IF D(P)<9 THEN D(P)=D(P)+1: RETURN
5030   D(P)=0
5040 NEXT P
5050 RETURN  ' wrapped from 9999999999 to 0000000000
5300 '===== build full right-aligned string S$ with no leading zeros =====
5310 ' find first non-zero digit position F (1..10); if all zero -> "0"
5320 F=0
5330 FOR I=1 TO 10
5340   IF D(I)<>0 AND F=0 THEN F=I
5350 NEXT I
5360 IF F=0 THEN TMP$="0"
5365 IF F<>0 THEN GOSUB 5380
5370 GOTO 5410
5380 TMP$=""
5390 FOR I=F TO 10
5400   TMP$=TMP$+CHR$(48+D(I))
5405 NEXT I
5410 PAD=10-LEN(TMP$)
5420 IF PAD<0 THEN PAD=0
5430 S$=STRING$(PAD,32)+TMP$
5440 RETURN
6000 '===== MAIN LOOP =====
6010 GOSUB 5000               ' increment value
6020 GOSUB 5300               ' build full field (spaces + digits)
6030 R=0: C=6: GOSUB 450      ' print entire 10-char field
6040 GOTO 6010