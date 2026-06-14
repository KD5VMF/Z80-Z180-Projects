# TMS ASM Builder IDE for SC720 / TMSEMU3

A friendly Windows IDE and build tool for making **Z80 / Z180 CP/M `.COM` programs** that use the **TMS9918A / TMSEMU3 video card** on Small Computer Central / RC2014-style systems.

This repository is meant to be easy for retro-computer builders: open the IDE, write or paste ASM, click build, and get transfer-ready output.

## What it does

- Edits Z80/TMS9918A assembly in a simple WinForms IDE.
- Highlights ASM source like a real IDE:
  - comments in green
  - labels in teal
  - opcodes in blue
  - directives in purple
  - strings in orange
  - numbers in light green
- Builds CP/M `.COM` files with bundled `sjasmplus.exe`.
- Also creates Intel HEX `.HEX` files starting at CP/M load address `0100h`.
- Keeps shared library files in `TMSAsmBuilder/Libs`.
- Creates clean build/project folders containing only the generated `.ASM` and `.HEX` files.
- Copies the latest `.COM`, `.ASM`, and `.HEX` into `TMSAsmBuilder/Out` for fast transfer.

## Hardware target

This was made for this kind of setup:

- Small Computer Central / RC2014-style Z80 or Z180 machine
- RomWBW CP/M
- TMSEMU3 or J.B. Langston-style TMS9918A video card
- Windows PC used as the build/transfer machine
- Tera Term or similar serial terminal for file transfer

The bundled example source uses J.B. Langston-style TMS9918A support routines and Z80 syntax.

## Repository layout

```text
.
├─ TMSAsmBuilder.sln
├─ TMSAsmBuilder/
│  ├─ MainForm.cs                 IDE and builder logic
│  ├─ Program.cs                  WinForms entry point
│  ├─ Assets/                     IDE icon
│  ├─ Libs/                       shared ASM support libraries
│  ├─ Templates/                  starter ASM templates
│  ├─ Tools/                      bundled assembler tool
│  ├─ Work/                       working ASM area
│  ├─ Builds/                     timestamped clean ASM + HEX outputs
│  └─ Out/                        latest ASM + COM + HEX output
├─ docs/                          user and developer notes
├─ build_gui.bat                  build the Windows app
├─ run_gui.bat                    run from source
└─ FIRST_RUN.bat                  simple first-run helper
```

## Quick start

1. Install the **.NET 8 SDK** or newer on Windows.
2. Download this repository ZIP and extract it.
3. Double-click `FIRST_RUN.bat`.
4. Click **Load Chess Template** or **New ASM**.
5. Click **Build .COM + .HEX**.
6. Use the files from:
   - `TMSAsmBuilder/Out` for latest `.COM`, `.ASM`, and `.HEX`
   - `TMSAsmBuilder/Builds/<name>_<timestamp>` for clean `.ASM` and `.HEX` project folders

## Transfer to CP/M using XMODEM

On CP/M:

```text
C>XM R CHESLIB1.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick the `.COM` from `TMSAsmBuilder/Out`.

## Transfer to CP/M using PIP + LOAD

This is useful when XMODEM is not available or is being difficult.

On CP/M:

```text
C>PIP CHESLIB1.HEX=CON:
```

In Tera Term, enable a small transmit delay, then send the `.HEX` as text:

```text
Setup -> Serial port -> Transmit delay: 5 ms/char and 50 ms/line
File -> Send file...
```

After the transfer finishes, press `Ctrl-Z`, then run:

```text
C>LOAD CHESLIB1
C>CHESLIB1
```

## Build behavior

The IDE uses a temporary internal build folder so `include "tms.asm"` and similar statements work normally.

Public timestamped build folders stay clean and receive only:

```text
PROGRAM.ASM
PROGRAM.HEX
```

The generated `.COM` is copied to `TMSAsmBuilder/Out` for XMODEM transfer, but it is not copied into the clean project/build folders.

## Third-party code and tools

This project includes support files and tooling so a user can get started quickly:

- `sjasmplus.exe` is bundled in `TMSAsmBuilder/Tools`.
- J.B. Langston TMS9918A/Z180/utility ASM support files are bundled in `TMSAsmBuilder/Libs`.

See `THIRD_PARTY_NOTICES.md` for details.

## Status

Current repo package: **REV4 GitHub-ready share package**

Main REV4 changes:

- IDE icon added.
- ASM syntax coloring added.
- Build folders no longer receive copied library files.
- Generated `.HEX` files are created alongside clean `.ASM` build copies.
- `RichTextBox` build fix applied.

## License

Project wrapper/IDE code in this repository is released under the MIT License unless noted otherwise.

Bundled third-party code/tools keep their original licenses. See `THIRD_PARTY_NOTICES.md`.
