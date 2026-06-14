# Troubleshooting

## The IDE opens but says sjasmplus is missing

Make sure this file exists:

```text
TMSAsmBuilder\Tools\sjasmplus.exe
```

Use the **Find sjasmplus.exe** button if the assembler is somewhere else.

## The assembler cannot find `tms.asm` or `z180.asm`

Make sure the support files are in:

```text
TMSAsmBuilder\Libs
```

The common files are:

```text
tms.asm
tmsfont.asm
z180.asm
utility.asm
```

You can also click **Download J.B. Langston Libs** in the IDE.

## The program builds but CP/M LOAD fails

Check these things:

- The `.HEX` transfer was completed with `Ctrl-Z` after `PIP NAME.HEX=CON:`.
- The terminal transmit delay is not too fast.
- Try `5 ms/char` and `50 ms/line` in Tera Term.
- Make sure you typed `LOAD NAME` without `.HEX`.
- Make sure the CP/M filename is 8.3-safe.

## The program starts but says TMS9918A not found

Check the graphics module and I/O configuration. The support library probes for the TMS port. If the hardware is not installed, not decoded at the expected port range, or not ready, the program will abort.

## The build folder has no COM file

That is intentional. The timestamped build folders are kept clean for CP/M text transfer and sharing:

```text
Builds\timestamp\NAME.ASM
Builds\timestamp\NAME.HEX
```

The matching `.COM` is copied to:

```text
TMSAsmBuilder\Out
```

## The program runs too fast on real hardware

Add a delay loop or wait for VDP timing inside the ASM program. The IDE only builds and transfers; runtime speed is controlled by your Z80/Z180 code.
