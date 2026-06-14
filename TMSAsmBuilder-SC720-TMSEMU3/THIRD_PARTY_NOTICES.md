# Third-party notices

This repository intentionally includes a few third-party files so a retro-computer user can build immediately without hunting for tools and library files.

## sjasmplus

Location:

```text
TMSAsmBuilder/Tools/sjasmplus.exe
```

Purpose: Z80 cross-assembler used by the IDE to build CP/M `.COM` files.

Upstream project: `z00m128/sjasmplus`

License: BSD / BSD-3-Clause, per the upstream repository and documentation.

## J.B. Langston TMS9918A support files

Location:

```text
TMSAsmBuilder/Libs/
```

Typical files:

```text
tms.asm
TmsFont.asm
z180.asm
utility.asm
```

Purpose: TMS9918A, Z180, font, and utility routines used by the example/template programs.

Upstream project: `jblang/TMS9918A`

License: MIT-style permission notice appears in the upstream README and in several of the bundled ASM support files. Preserve the original notices when redistributing.

## Font note

`TmsFont.asm` identifies the 6x8 bitmap font source as Oleg Kosenkov's raster-fonts project. Keep that attribution with the file.

## Project wrapper code

The C# IDE/builder code and project documentation added here are MIT licensed unless a file says otherwise.
