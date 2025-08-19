10 REM ============================================================
20 REM  MANDELBR.BAS  -  ANSI Color Mandelbrot for MBASIC-80 / CP/M
30 REM  SC7xx Z180 (UART text). 80x24, draws line-by-line forever.
40 REM  Each frame chooses a random view and random color palette.
50 REM  Keys:  Q = quit   (checked each line)
60 REM ============================================================
70 ESC$=CHR$(27)+"[": CLS$=ESC$+"2J": HOME$=ESC$+"H": HIDE$=ESC$+"?25l": SHOW$=E
SC$+"?25h": RST$=ESC$+"0m"
80 COLS=80: ROWS=24: MAXIT=48        'adjust MAXIT for detail/speed (24..96 reas
onable)
90 DIM RX(80)                        'precomputed real-axis coordinates per colu
mn
100 DIM PAL$(8)                      'ANSI 30..37 (FG colors)
110 PAL$(1)="31":PAL$(2)="33":PAL$(3)="32":PAL$(4)="36":PAL$(5)="34":PAL$(6)="35
":PAL$(7)="37":PAL$(8)="30"
120 PRINT CLS$;HOME$;HIDE$;
130 REM ---- Seed randomness from key timing so each run differs ----
140 PRINT "Press any key to start Mandelbrot ...";
150 T=0: A$=INKEY$: IF A$="" THEN T=T+1: GOTO 150
160 X=RND(-T)
170 PRINT CLS$;HOME$;
180 REM ===================== MAIN FRAME LOOP ======================
190 FRAME=FRAME+1
200 REM ---- Pick a random view window (center & width) ------------
210 REM Center near interesting bits; width gives zoom (smaller = deeper zoom)
220 CX=-.75+(RND(1)-.5)*1.6
230 CY=(RND(1)-.5)*1.4
240 W=2.8*(.35+RND(1)*.65)       'random width ~0.98..2.8
250 H=W*(ROWS/COLS)
260 XMIN=CX-W/2: XMAX=CX+W/2: YMAX=CY+H/2: YMIN=CY-H/2
270 DX=W/(COLS-1): DY=H/(ROWS-1)
280 FOR C=1 TO COLS: RX(C)=XMIN+(C-1)*DX: NEXT C
290 REM ---- Randomize color palette ordering each frame -----------
300 FOR I=1 TO 16
310 J=INT(RND(1)*I)+1
320 TMP$=PAL$(I)
321 PAL$(I)=PAL$(J)
322 PAL$(J)=TMP$
330 NEXT I
340 REM ---- Clear, Home, tiny header (disabled to maximize speed) -
350 PRINT ESC$;"2J";ESC$;"H";
360 REM ==================== RENDER LINES ==========================
370 FOR R=1 TO ROWS
380   Y=YMAX-(R-1)*DY
390   LASTC=-99
400   FOR C=1 TO COLS
410     X=RX(C)
420     REM --- Fast inside tests (cardioid & period-2 bulb) -------
430     XR=X: YR=Y
440     Q=(XR-.25)*(XR-.25)+YR*YR
450     IF Q*(Q+(XR-.25))<.25*YR*YR THEN IT=MAXIT: GOTO 520
460     IF (XR+1)*(XR+1)+YR*YR<=.0625 THEN IT=MAXIT: GOTO 520
470     REM --- Iterate z <- z^2 + c --------------------------------
480     ZX=0: ZY=0: IT=0
490     XX=0: YY=0
500     IT=IT+1
510     XX=ZX*ZX: YY=ZY*ZY: IF XX+YY>4 THEN GOTO 520 ELSE ZY=2*ZX*ZY+Y: ZX=XX-YY
+X: IF IT<MAXIT THEN GOTO 500
520     REM --- Map iteration to character & color -----------------
530 IF IT=MAXIT THEN CH$=" ": COLIDX=0: GOTO 550
535 ILEV=INT((IT/MAXIT)*9)+1
536 IF ILEV<1 THEN ILEV=1
540 CH$=MID$(" .:-=+*#%@",ILEV,1)
545 COLIDX=((IT-1)-INT((IT-1)/8)*8)+1
550     IF COLIDX<>LASTC THEN IF COLIDX=0 THEN PRINT RST$; : LASTC=0 ELSE PRINT
ESC$;PAL$(COLIDX);"m"; : LASTC=COLIDX
560     PRINT CH$;
570   NEXT C
580   PRINT RST$;                 'reset color at end of line
590   REM --- Key check per line: Q to quit ------------------------
600   K$=INKEY$: IF K$="Q" OR K$="q" THEN PRINT SHOW$;RST$;: END
610 NEXT R
620 REM ---- Immediately move to a brand-new random view ----------
630 GOTO 190
640 REM ==================== END PROGRAM ===========================
