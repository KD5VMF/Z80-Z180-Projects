# Tools, Libraries, Links, and Credits

This program is useful because it joins several excellent tools and retro-computing projects into one easy workflow.

## TMS ASM Builder IDE

This repo's Windows IDE code glues the workflow together:

```text
ASM source -> sjasmplus -> COM bytes -> Intel HEX -> CP/M LOAD -> COM program
```

The IDE source code is in:

```text
TMSAsmBuilder\Program.cs
TMSAsmBuilder\MainForm.cs
```

## sjasmplus

Project:

```text
https://github.com/z00m128/sjasmplus
```

Releases:

```text
https://github.com/z00m128/sjasmplus/releases/latest
```

Role in this repo:

- Assembles Z80-style source on Windows.
- Supports the syntax used by the TMS9918A examples and libraries.
- Produces the raw CP/M `.COM` bytes used by this IDE.

Credit: the sjasmplus project and its contributors.

## J.B. Langston TMS9918A library and examples

Project:

```text
https://github.com/jblang/TMS9918A
```

Role in this repo:

- TMS9918A setup routines.
- Text, tile, bitmap, sprite, color, and VDP helper routines.
- Z180 utility routines used by many examples.
- Working style that this IDE is designed around.

Credit: J.B. Langston. Copyright/license headers are preserved in the ASM files.

## Oleg Kosenkov / raster-fonts

Source noted in `tmsfont.asm`:

```text
https://github.com/idispatch/raster-fonts/blob/master/font-6x8.c
```

Role in this repo:

- 6x8 bitmap font data used by TMS9918A text/graphics examples.

Credit: Oleg Kosenkov / raster-fonts, as noted in the source header.

## RomWBW

Project:

```text
https://github.com/wwarthen/RomWBW
```

Role in this workflow:

- Provides the CP/M environment on many Z80/Z180 retro systems.
- Provides the kind of CP/M setup used on Small Computer Central systems.
- Gives you the CP/M side where `PIP`, `LOAD`, `XM`, and the generated `.COM` programs run.

Credit: Wayne Warthen and the RomWBW contributors.

## Small Computer Central SC720

Hardware/category page:

```text
https://smallcomputercentral.com/category/hardware/
```

SC720 product page:

```text
https://lectronz.com/products/sc720-rcbus-80pin-z80-romwbw-cpm-motherboard
```

Role in this workflow:

- Real Z80 CP/M hardware target.
- Excellent system for running RomWBW and CP/M programs.

Credit: Small Computer Central.

## TMSEMU3

Information page:

```text
https://smallcomputercentral.com/third-party-rcbus/tmsemu3/
```

Role in this workflow:

- TMS9918A-style graphics target used by the programs created with this IDE.
- Lets the Z80 program draw color graphics / text on a display.

Credit: TMSEMU3 hardware/software creators and documentation authors.

## Tera Term

Project page:

```text
https://teratermproject.github.io/index-en.html
```

Role in this workflow:

- Serial terminal.
- Sends Intel HEX text using `File -> Send file...`.
- Sends `.COM` binary through XMODEM when using `XM.COM`.

Credit: Tera Term Project.

## CP/M LOAD

CP/M `LOAD` converts Intel HEX machine-code text into a CP/M `.COM` executable.

Role in this workflow:

```text
C>LOAD PACMAN
```

turns:

```text
PACMAN.HEX
```

into:

```text
PACMAN.COM
```

Credit: Digital Research CP/M tooling and documentation.
