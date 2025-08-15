10 REM === DIVISOR CLASSIFICATION TABLE (MBASIC-80) ===
20 PRINT "Divisor classification 1..N"
30 INPUT "Upper limit N"; LIM
40 IF LIM<1 THEN PRINT "Nothing to do.": END
50 PC=0: AC=0: DC=0: MAXEX=0: MAXN=1
60 FOR N=1 TO LIM
70   GOSUB 500
80   IF S=N THEN K$="PERFECT": PC=PC+1 ELSE IF S>N THEN K$="ABUNDANT": AC=AC+1 ELSE K$="DEFICIENT": DC=DC+1
90   IF S>N THEN EX=S-N: IF EX>MAXEX THEN MAXEX=EX: MAXN=N
100  PRINT N;",";S;",";K$
110  IF N-INT(N/100)*100=0 THEN PRINT "n=";N;"  perfect=";PC;" abundant=";AC;" deficient=";DC
120 NEXT N
130 PRINT "Done."
140 PRINT "Perfect=";PC;"  Abundant=";AC;"  Deficient=";DC
150 PRINT "Most abundant excess=";MAXEX;" at n=";MAXN
160 END
500 REM --- sum of proper divisors of N -> S ---
510 IF N=1 THEN S=0: RETURN
520 S=1
530 SQ=INT(SQR(N))
540 FOR D=2 TO SQ
550   IF N-INT(N/D)*D=0 THEN Q=N/D: IF Q=D THEN S=S+D ELSE S=S+D+Q
560 NEXT D
570 RETURN
