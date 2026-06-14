# Intel HEX Notes

The IDE writes Intel HEX from the generated `.COM` file.

## Start address

CP/M `.COM` programs load at:

```text
0100h
```

So the first Intel HEX data record is addressed at `0100h`.

## Record size

The converter writes 16 bytes per data record.

## EOF record

The file ends with:

```text
:00000001FF
```

That is the standard Intel HEX end-of-file record.

## Size check

A CP/M `.COM` loaded at `0100h` must fit in the remaining transient program area. The IDE also refuses to HEX-convert a raw `.COM` that is too large for a normal 64K address image starting at `0100h`.

## Why convert COM to HEX instead of assembling HEX directly?

This keeps the build pipeline simple:

1. The assembler produces the exact `.COM` byte stream.
2. The IDE translates those exact bytes into Intel HEX text.
3. CP/M `LOAD` reconstructs the `.COM` from that text.

That means the XMODEM `.COM` method and the PIP/LOAD `.HEX` method come from the same built program.
