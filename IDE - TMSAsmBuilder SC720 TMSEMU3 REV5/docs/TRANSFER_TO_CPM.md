# Transfer to RomWBW CP/M

The IDE produces two useful outputs:

- `.COM` - the finished CP/M executable.
- `.HEX` - Intel HEX text version that CP/M `LOAD` can convert back to `.COM`.

## Best simple method: PIP + LOAD

This method is slower than XMODEM but very useful because Intel HEX is plain text.

Example output name:

```text
PACMAN.COM
```

The generated HEX file will be:

```text
PACMAN.HEX
```

On CP/M:

```text
C>PIP PACMAN.HEX=CON:
```

In Tera Term, set a safe transmit delay:

```text
Setup -> Serial port -> Transmit delay
5 ms/char
50 ms/line
```

Then:

```text
File -> Send file...
```

Select `PACMAN.HEX` from the clean timestamped build folder.

When the transfer is done, press:

```text
Ctrl-Z
```

Then convert the HEX file into a COM file:

```text
C>LOAD PACMAN
```

Then run it:

```text
C>PACMAN
```

## XMODEM method

If your CP/M system has `XM.COM` and XMODEM works:

```text
C>XM R PACMAN.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Select:

```text
TMSAsmBuilder\Out\PACMAN.COM
```

Then run:

```text
C>PACMAN
```

## Why HEX is nice

Intel HEX is line-based ASCII text. Even if binary transfers are annoying, you can paste or send HEX text through the console, then let CP/M `LOAD` rebuild the `.COM` file.
