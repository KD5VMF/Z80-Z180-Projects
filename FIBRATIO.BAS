10 REM *** FIBONACCI SEQUENCE WITH RATIO (MBASIC-80) ***
20 PRINT "Fibonacci with ratio (phi). How many terms?";
30 INPUT N
40 IF N < 2 THEN LET N=2
50 LET A = 0: LET B = 1
60 PRINT " TERM";TAB(10);"FIB";TAB(24);"RATIO TO PREV"
70 PRINT "----";TAB(10);"---";TAB(24);"-------------"
80 FOR I = 1 TO N
90   PRINT USING "####"; I;
100  PRINT TAB(10); USING "############"; B;
110  IF A <> 0 THEN LET R = B / A: PRINT TAB(24); USING "##.######"; R ELSE PRINT TAB(24);"N/A"
120  LET C = A + B
130  LET A = B
140  LET B = C
150 NEXT I
160 END
