# CP/M Transfer Guide

The IDE creates two transfer-friendly file types:

- `.COM` — ready to run on CP/M after binary transfer.
- `.HEX` — Intel HEX text, useful for `PIP` + `LOAD`.

## XMODEM transfer

Build the project, then use the file in:

```text
TMSAsmBuilder/Out/BALLS.COM
```

On CP/M:

```text
C>XM R BALLS.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick `BALLS.COM`.

Then run:

```text
C>BALLS
```

## PIP + LOAD transfer

Build the project, then use the file in:

```text
TMSAsmBuilder/Out/BALLS.HEX
```

On CP/M:

```text
C>PIP BALLS.HEX=CON:
```

In Tera Term, send the `.HEX` as a text file. A small transmit delay is recommended on many old serial setups:

```text
5 ms/char
50 ms/line
```

Finish with `Ctrl-Z`, then run:

```text
C>LOAD BALLS
C>BALLS
```

## Why the HEX starts at 0100h

CP/M `.COM` programs load at address `0100h`. The IDE writes Intel HEX records with a base address of `0100h`, matching the `org 100h` used by the demo and by normal CP/M application code.
