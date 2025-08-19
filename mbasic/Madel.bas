10 REM ============================================================
20 REM  MANDELBG.BAS - ANSI Background Color Mandelbrot (80x24)
30 REM  SC131 Z180 (UART text). Uses only 7-bit ASCII + ANSI SGR.
40 REM  Q to quit. Each frame randomizes the color palette.
50 REM ============================================================
60 ESC$=CHR$(27)+"[": CLS$=ESC$+"2J": HOME$=ESC$+"H": HIDE$=ESC$+"?25l": SHOW$=ESC$+"?25h": RST$=ESC$+"0m"
70 COLS=80: ROWS=24: MAXIT=48
80 DIM RX(80)
90 DIM PB$(8)              'background colors: 40..47
100 PB$(1)="41":PB$(2)="43":PB$(3)="42":PB$(4)="46":PB$(5)="44":PB$(6)="45":PB$(7)="47":PB$(8)="40"
110 PRINT CLS$;HOME$;HIDE$;ESC$;"40m";RST$;
120 PRINT "Press any key to start Mandelbrot ...";
130 T=0: A$=INKEY$: IF A$="" THEN T=T+1: GOTO 130
140 X=RND(-T)
150 PRINT CLS$;HOME$;ESC$;"40m";RST$;

160 REM ===================== MAIN FRAME LOOP ======================
170 FR=FR+1
180 CX=-.75+(RND(1)-.5)*1.6
190 CY=(RND(1)-.5)*1.4
200 W=2.8*(.35+RND(1)*.65)
210 H=W*(ROWS/COLS)
220 XMIN=CX-W/2: XMAX=CX+W/2: YMAX=CY+H/2: YMIN=CY-H/2
230 DX=W/(COLS-1): DY=H/(ROWS-1)
240 FOR C=1 TO COLS: RX(C)=XMIN+(C-1)*DX: NEXT C

250 REM ----- Shuffle background palette each frame -----
260 FOR I=8 TO 2 STEP -1
270 J=INT(RND(1)*I)+1
280 TMP$=PB$(I): PB$(I)=PB$(J): PB$(J)=TMP$
290 NEXT I

300 PRINT ESC$;"2J";ESC$;"H";ESC$;"40m";
310 REM ==================== RENDER =====================
320 FOR R=1 TO ROWS
330  Y=YMAX-(R-1)*DY
340  LC=-99
350  FOR C=1 TO COLS
360    X=RX(C)
370    REM ---- cardioid / bulb quick-inside tests ----
380    XR=X: YR=Y
390    Q=(XR-.25)*(XR-.25)+YR*YR
400    IF Q*(Q+(XR-.25))<.25*YR*YR THEN IT=MAXIT: GOTO 450
410    IF (XR+1)*(XR+1)+YR*YR<=.0625 THEN IT=MAXIT: GOTO 450
420    REM ---- iterate z <- z^2 + c ----
430    ZX=0: ZY=0: IT=0: XX=0: YY=0
440    IT=IT+1
445    XX=ZX*ZX: YY=ZY*ZY
446    IF XX+YY>4 THEN 450
447    ZY=2*ZX*ZY+Y: ZX=XX-YY+X: IF IT<MAXIT THEN GOTO 440
450    REM ---- map to bg color (space pixel) ----
460    CI=0
470    IF IT<MAXIT THEN CI=((IT-1)-INT((IT-1)/8)*8)+1
480    IF CI<>LC THEN GOSUB 900
490    PRINT " ";
500  NEXT C
510  PRINT RST$;
520  K$=INKEY$: IF K$="Q" OR K$="q" THEN PRINT SHOW$;RST$;: END
530 NEXT R
540 GOTO 170

900 REM ---- SETCOLOR: uses CI, updates LC ----
910 IF CI=0 THEN PRINT ESC$;"40m";: LC=0: RETURN
920 PRINT ESC$;PB$(CI);"m";: LC=CI: RETURN
