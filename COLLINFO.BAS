10 REM === COLLATZ RECORD HUNTER with Detailed Intro (MBASIC-80) ===
20 REM LEDs show low byte of the current Collatz value (SC719 port 00h)
30 LEDPORT = &H00
40 GOSUB 8000
50 INPUT "Upper limit N (0 = very high)"; LIM
60 IF LIM=0 THEN LIM=9999999
70 INPUT "Save results to file (Y/N)"; AN$
80 SAVING = (AN$="Y" OR AN$="y")
90 IF SAVING THEN OPEN "O",1,"COLLSTAT.TXT": PRINT #1,"n,steps,peak,record_type,peak/n,avg_steps"
100 BESTS=0: BESTSN=1
110 BESTP=0: BESTPN=1
120 TOTALS=0: COUNTN=0
130 FOR N=1 TO LIM
140   X=N: S=0: P=X: T=0
150   IF X=1 THEN 200
160   IF X-2*INT(X/2)=0 THEN X=X/2 ELSE X=3*X+1
170   IF X>P THEN P=X
175   S=S+1
177   T=T+1: IF T-8*INT(T/8)=0 THEN LB=X-256*INT(X/256): OUT LEDPORT,LB
180   GOTO 160
200   COUNTN=COUNTN+1: TOTALS=TOTALS+S
210   AVG = TOTALS/COUNTN
220   AMP = P/N
230   REC$ = ""
240   IF S>BESTS THEN BESTS=S: BESTSN=N: REC$="NEW_MAX_STEPS"
250   IF P>BESTP THEN BESTP=P: BESTPN=N: IF REC$="" THEN REC$="NEW_MAX_PEAK" ELSE REC$=REC$+"+MAX_PEAK"
260   IF REC$<>"" THEN GOSUB 9000
270   IF SAVING AND REC$<>"" THEN PRINT #1, N;",";S;",";P;",";REC$;",";AMP;",";AVG
280   IF N-INT(N/100)*100=0 THEN GOSUB 9100
290 NEXT N
300 IF SAVING THEN PRINT #1,"SUMMARY: best_steps=";BESTS;" at n=";BESTSN: PRINT #1,"SUMMARY: best_peak=";BESTP;" at n=";BESTPN: PRINT #1,"SUMMARY: avg_steps=";AVG: CLOSE 1
310 PRINT : PRINT "Done."; : IF SAVING THEN PRINT " See COLLSTAT.TXT"
320 END
8000 REM --- Detailed program explanation (ASCII-only) ---
8010 PRINT "COLLATZ RECORD HUNTER"
8020 PRINT "------------------------------------------------"
8030 PRINT "What this does:"
8040 PRINT "  * Scan numbers 1..N. For each n, apply:"
8050 PRINT "      even: n := n/2"
8060 PRINT "      odd : n := 3*n + 1"
8070 PRINT "    Count steps to reach 1 and track the largest value (peak)."
8080 PRINT
8090 PRINT "On-screen abbreviations:"
8100 PRINT "  n   = start value"
8110 PRINT "  s   = steps to reach 1"
8120 PRINT "  p   = peak (largest value in the chain)"
8130 PRINT "  a   = amplification = peak / n"
8140 PRINT "  avg = running average of s over tested n"
8150 PRINT
8160 PRINT "Records:"
8170 PRINT "  * When a NEW record is found, we print a line with a tag:"
8180 PRINT "    [NEW_MAX_STEPS], [NEW_MAX_PEAK], or both."
8190 PRINT "  * Every 100 n we print a compact progress line."
8200 PRINT
8210 PRINT "LEDs (SC719, port 00h):"
8220 PRINT "  * LEDs show the low 8 bits of the CURRENT chain value."
8230 PRINT "  * Updated about once every 8 steps."
8240 PRINT
8250 PRINT "Saving results:"
8260 PRINT "  * Choose Y to save new-record lines to COLLSTAT.TXT; N for screen-only."
8270 PRINT
8280 PRINT "Controls and tips:"
8290 PRINT "  * Press Ctrl-C any time to quit."
8300 PRINT "  * To use a different LED port, edit line 30 (LEDPORT = &H..)."
8310 PRINT "  * For a first run, try N = 20000."
8320 PRINT : PRINT "Press ENTER to continue...";
8330 LINE INPUT A$
8340 PRINT
8350 RETURN
9000 REM --- compact record line (<=80 columns) ---
9010 NS$=MID$(STR$(N),2)
9020 SS$=MID$(STR$(S),2)
9030 PS$=MID$(STR$(P),2)
9040 A4=INT(AMP*10000+.5)/10000
9050 V4=INT(AVG*10000+.5)/10000
9060 AS$=MID$(STR$(A4),2)
9070 VS$=MID$(STR$(V4),2)
9080 PRINT "n=";NS$;" s=";SS$;" p=";PS$;" a=";AS$;" avg=";VS$;" [";REC$;"]"
9090 RETURN
9100 REM --- compact progress line ---
9110 NS$=MID$(STR$(N),2)
9120 BS$=MID$(STR$(BESTS),2)
9130 BN$=MID$(STR$(BESTSN),2)
9140 BP$=MID$(STR$(BESTP),2)
9150 BPN$=MID$(STR$(BESTPN),2)
9160 V4=INT(AVG*10000+.5)/10000: VS$=MID$(STR$(V4),2)
9170 PRINT ">> n=";NS$;"  s*=";BS$;"@";BN$;"  p*=";BP$;"@";BPN$;"  avg=";VS$
9180 RETURN
