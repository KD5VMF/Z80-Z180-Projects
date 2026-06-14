# Third-party notices

This repository intentionally includes a few third-party files so a retro-computer user can build immediately without hunting for tools and library files.

## sjasmplus

Location:

```text
TMSAsmBuilder/Tools/sjasmplus.exe
```

Purpose:

`sjasmplus.exe` is the Z80-family cross assembler that turns the IDE's `org 100h` source into a raw CP/M `.COM` binary.

Upstream project:

```text
z00m128/sjasmplus
```

License:

The upstream project identifies itself as BSD-3-Clause licensed. Keep the upstream license terms with redistributed copies of the binary/source.

## J.B. Langston TMS9918A support files

Location:

```text
TMSAsmBuilder/Libs/
```

Typical important files:

```text
tms.asm
tmsfont.asm
z180.asm
utility.asm
```

Purpose:

These files provide the video, Z180 timing, font, and CP/M helper routines used by TMS9918A/TMSEMU3 demo programs.

- `tms.asm` contains TMS9918A/TMSEMU3 probe/setup/VRAM/color/sprite/text helper routines.
- `z180.asm` contains Z180 detection, clock, wait, and related helper routines.
- `utility.asm` contains CP/M BDOS console/string/key helpers.
- `tmsfont.asm` contains the text font data used by text-mode examples.

Upstream project:

```text
jblang/TMS9918A
```

License:

J.B. Langston's files include an MIT-style permission notice and copyright notice. Preserve those notices when redistributing.

## Font note

`tmsfont.asm` identifies the 6x8 bitmap font source as Oleg Kosenkov's raster-fonts project. Keep that attribution with the file.

## Bundled demo

Location:

```text
TMSAsmBuilder/Templates/BOUNCE.ASM
```

Purpose:

This is the bundled bouncing sprite demo for SC720/TMSEMU3-style builds. It uses the shared library files from `Libs` and does not require `tmsfont.asm`.

## Project wrapper code

The C# IDE/builder code, packaging scripts, and documentation added here are MIT licensed unless a file says otherwise.
