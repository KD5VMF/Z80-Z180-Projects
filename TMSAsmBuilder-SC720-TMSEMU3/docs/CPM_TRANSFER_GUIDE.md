# CP/M transfer guide

This IDE gives you two useful transfer paths.

## Option A: XMODEM `.COM`

Use this when `XM.COM` is available on the CP/M machine.

On CP/M:

```text
C>XM R PROGRAM.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Choose the `.COM` file from:

```text
TMSAsmBuilder/Out/
```

Then run:

```text
C>PROGRAM
```

## Option B: PIP + LOAD with `.HEX`

Use this when XMODEM is unavailable or annoying.

On CP/M:

```text
C>PIP PROGRAM.HEX=CON:
```

In Tera Term:

```text
Setup -> Serial port
Transmit delay: 5 ms/char and 50 ms/line
File -> Send file...
```

Choose the `.HEX` from the timestamped build folder.

When the text send finishes, press:

```text
Ctrl-Z
```

Then convert HEX to COM:

```text
C>LOAD PROGRAM
```

Run it:

```text
C>PROGRAM
```

## Why HEX starts at 0100h

CP/M `.COM` programs load at address `0100h`. The IDE converts raw `.COM` bytes into Intel HEX data records starting at `0100h`, so CP/M `LOAD` recreates the correct `.COM` program.
