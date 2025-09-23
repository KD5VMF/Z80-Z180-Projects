10 REM =========================================================
20 REM  GOLDBACH LIVE - MBASIC-80 (SC131 / Z80)
30 REM  - Even N:  print ALL pairs p+q=N live
40 REM  - Range:  for each even E, print the FIRST pair live
50 REM  - Odd  N: print ALL triples a+b+c=N live (with a<=b<=c)
60 REM  Primality: trial division up to SQR(X), odd divisors only
70 REM =========================================================
80 CLEAR
90 PRINT "Goldbach Live (MBASIC-80) - SC131"
100 PRINT "1) Even N as sum of TWO primes (print ALL pairs)"
110 PRINT "2) Check ALL evens up to a limit (print FIRST pair for each)"
120 PRINT "3) Odd N as sum of THREE primes (print ALL triples)"
130 PRINT "Q) Quit"
140 PRINT
150 INPUT "Select (1/2/3 or Q): ",M$
160 IF M$="Q" OR M$="q" THEN END
170 IF M$<>"1" AND M$<>"2" AND M$<>"3" THEN PRINT "Invalid. Try again.":PRINT:GOTO 90

180 IF M$="1" THEN GOSUB 1000: GOTO 90
190 IF M$="2" THEN GOSUB 2000: GOTO 90
200 IF M$="3" THEN GOSUB 3000: GOTO 90
210 GOTO 90

990 REM --------------------[ Option 1: Even N, print ALL pairs ]----------------
1000 PRINT:INPUT "Enter EVEN N (>2, <=32766 advised): ",N
1010 IF N<=2 THEN PRINT "N must be > 2.":RETURN
1020 IF N/2<>INT(N/2) THEN PRINT "N is not even.":RETURN
1030 PRINT:PRINT "Searching ALL prime pairs p+q =";N;" ..."
1040 FOUND=0
1050 H=INT(N/2)
1060 FOR P=2 TO H
1070   X=P: GOSUB 9000: IF PFLAG=0 THEN GOTO 1120
1080   Q=N-P
1090   IF Q<2 THEN GOTO 1120
1100   X=Q: GOSUB 9000: IF PFLAG=0 THEN GOTO 1120
1110   PRINT " ";N;" = ";P;" + ";Q: FOUND=FOUND+1
1120 NEXT P
1130 IF FOUND=0 THEN PRINT "No decomposition found (unexpected for even N>2)."
1140 PRINT "Total pairs: ";FOUND
1150 RETURN

1990 REM --------[ Option 2: Range of evens, print FIRST pair for each ]---------
2000 PRINT:INPUT "Check evens up to (<=32766 recommended): ",L
2010 IF L<4 THEN PRINT "Limit must be >=4.":RETURN
2020 IF L>32766 THEN PRINT "Using 32766 max.":L=32766
2030 PRINT:PRINT "Checking evens 4,6,8,...,";L;"  (prints first pair for each)"
2040 FAIL=0: CNT=0
2050 FOR E=4 TO L STEP 2
2060   N=E: FOUND=0
2070   H=INT(N/2)
2080   FOR P=2 TO H
2090     X=P: GOSUB 9000: IF PFLAG=0 THEN GOTO 2140
2100     Q=N-P
2110     IF Q<2 THEN GOTO 2140
2120     X=Q: GOSUB 9000: IF PFLAG=0 THEN GOTO 2140
2130     PRINT " ";N;" = ";P;" + ";Q
2135     FOUND=1: GOTO 2150
2140   NEXT P
2150   IF FOUND=0 THEN PRINT " FAILED at ";N: FAIL=FAIL+1
2160   CNT=CNT+1
2170 NEXT E
2180 PRINT:PRINT "Checked ";CNT;" evens.  Failures: ";FAIL
2190 RETURN

2990 REM ---------------[ Option 3: Odd N, print ALL triples ]-------------------
3000 PRINT:INPUT "Enter ODD N (>=7, <=32767 advised): ",N
3010 IF N<7 THEN PRINT "Odd N must be >=7.":RETURN
3020 IF N/2=INT(N/2) THEN PRINT "N is not odd.":RETURN
3030 PRINT:PRINT "Searching ALL triples a+b+c =";N;" (a<=b<=c) ..."
3040 FOUND=0
3050 FOR A=2 TO N-4
3060   X=A: GOSUB 9000: IF PFLAG=0 THEN GOTO 3140
3070   S=N-A
3080   FOR B=A TO S-2
3090     X=B: GOSUB 9000: IF PFLAG=0 THEN GOTO 3135
3100     C=S-B
3110     IF C<B THEN GOTO 3135
3120     X=C: GOSUB 9000: IF PFLAG=0 THEN GOTO 3135
3125     PRINT " ";N;" = ";A;" + ";B;" + ";C
3126     FOUND=FOUND+1
3135   NEXT B
3140 NEXT A
3150 IF FOUND=0 THEN PRINT "No triple found (should exist for odd N>=7)."
3160 PRINT "Total triples: ";FOUND
3170 RETURN

8990 REM --------------------[ Subroutine: IsPrime(X)->PFLAG ]-------------------
9000 REM Input: X (>=0). Output: PFLAG=1 if prime, else 0
9010 IF X<2 THEN PFLAG=0: RETURN
9020 IF X=2 THEN PFLAG=1: RETURN
9030 IF (X/2)=INT(X/2) THEN PFLAG=0: RETURN
9040 L=INT(SQR(X))
9050 D=3
9060 PFLAG=1
9070 IF D>L THEN RETURN
9080 IF (X/D)=INT(X/D) THEN PFLAG=0: RETURN
9090 D=D+2
9100 IF D<=L THEN GOTO 9080
9110 RETURN

9990 REM ===========================[ END OF PROGRAM ]==========================
