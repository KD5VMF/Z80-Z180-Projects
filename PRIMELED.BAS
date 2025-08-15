10 REM === PRIME + LED + STATS (MBASIC-80) ===
20 REM LEDs assumed at I/O port 00h (change LEDPORT if needed)
30 LEDPORT = &H00
40 PRINT "Prime+LED+Stats  |  LEDs show low byte of prime on port 00h"
50 PRINT "Output file: PRIMESTA.TXT   (Ctrl-C to quit)"
60 INPUT "Upper limit N (0 = very high)"; LIM
70 IF LIM=0 THEN LIM=9999999
80 OPEN "O",1,"PRIMESTA.TXT"
90 PRINT #1,"prime,gap,count,maxgap"
100 PREV=0: COUNT=0: MAXG=0: MG1=0: MG2=0
110 FOR N=2 TO LIM
120   IF N>2 AND N-2*INT(N/2)=0 THEN 210
130   X=N: GOSUB 500
140   IF F=0 THEN 210
150   COUNT=COUNT+1
160   IF PREV=0 THEN GAP=0 ELSE GAP=N-PREV
170   IF GAP>MAXG THEN MAXG=GAP: MG1=PREV: MG2=N
180   PRINT USING "#########"; N; : PRINT "  gap=";GAP;"  count=";COUNT
185   LB = N - 256*INT(N/256) : OUT LEDPORT, LB
186   PRINT #1, N;",";GAP;",";COUNT;",";MAXG
200   IF COUNT-INT(COUNT/100)*100=0 THEN PRINT ">> n=";N;"  maxgap=";MAXG;" (";MG1;"->";MG2;")"
205   PREV=N
210 NEXT N
220 PRINT "Done. See PRIMESTA.TXT"
230 PRINT #1,"SUMMARY: primes=";COUNT;" maxgap=";MAXG;" between ";MG1;" and ";MG2
240 CLOSE 1
250 END
500 REM --- PRIME TEST: X in, F=1 if prime else 0 ---
510 IF X<2 THEN F=0: RETURN
520 IF X=2 THEN F=1: RETURN
530 IF X-2*INT(X/2)=0 THEN F=0: RETURN
540 S=INT(SQR(X)) : D=3
550 IF D>S THEN F=1: RETURN
560 IF X-INT(X/D)*D=0 THEN F=0: RETURN
570 D=D+2 : GOTO 550
