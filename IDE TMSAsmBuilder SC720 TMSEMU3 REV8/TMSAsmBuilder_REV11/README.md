# TMS ASM Builder REV11 Latest IDE

**Portable Windows ASM IDE for SC720 / SC700 / Z80-Z180 systems using TMSEMU3 / TMS9918A graphics.**

REV11 is the polished editor release: it opens with a ready-to-build CP/M Hello World, restores proper ASM syntax coloring, and keeps the REV10A editor stability and RAM cleanup fixes.

## Run it

Double-click:

```text
TMSAsmBuilder.exe
```

Keep these folders beside the EXE:

```text
Tools\
Libs\
Assets\
Templates\
Work\
Builds\
Out\
```

The IDE automatically finds `Tools\sjasmplus.exe` and `Libs\` when they are beside the EXE.

## REV11 upgrades

- **Proper ASM-side text color** in the source editor.
  - Comments, strings, labels, assembler directives, Z80/Z180 mnemonics, registers, and numbers have distinct colors.
  - Coloring is debounced and scroll-position-safe so it should not yank the editor back upward.
- **Default Hello World on first start** using `Templates\HELLO.ASM`.
- **Ready-to-build default program**: press **Build COM+HEX** and it creates `HELLO.COM` and `HELLO.HEX`.
- **REV10A editor fixes preserved**: better resizing, forced scrollbars, and no editor snap-back behavior.
- **RAM cleanup preserved**: stale temp folder cleanup, log trimming, and memory compaction requests after heavy loads/builds.
- **REV10 build engine preserved**: background build thread, Cancel Build, large ASM loading progress screen, async open/save, timestamped build folders, and latest output mirror.

## Folder layout

```text
TMSAsmBuilder_REV11_LATEST_IDE\
├─ TMSAsmBuilder.exe              Ready-to-run Windows IDE
├─ TMSAsmBuilder.dll/deps/json    Runtime files for the IDE
├─ Assets\                        Icon and UI assets
├─ Tools\                         sjasmplus.exe assembler
├─ Libs\                          TMSEMU3, Z180, SC700, RomWBW helper ASM libs
├─ Templates\                     HELLO.ASM, NEWPROG.ASM, BALLS.ASM
├─ Work\                          Editable demo/source programs
├─ Builds\                        Timestamped build output folders
├─ Out\                           Latest quick-output mirror
├─ src\TMSAsmBuilder\             Clean C# WinForms source
├─ scripts\                       Windows helper scripts
└─ docs\                          Extra notes
```

## Default first-start program

REV11 opens with:

```asm
        org     100h

Start:
        ld      de,HelloMsg
        call    strout
        rst     0

HelloMsg:
        db      13,10,'Hello from TMS ASM Builder REV11!',13,10,'$'

        include "utility.asm"
        end
```

Press **Build COM+HEX** and the latest files are mirrored to:

```text
Out\HELLO.ASM
Out\HELLO.HEX
Out\HELLO.COM
```

## Build output

REV11 creates a timestamped folder like:

```text
Builds\HELLO_20260620_153000\HELLO.ASM
Builds\HELLO_20260620_153000\HELLO.HEX
Builds\HELLO_20260620_153000\HELLO.COM
```

It also mirrors the newest output to:

```text
Out\HELLO.ASM
Out\HELLO.HEX
Out\HELLO.COM
```

## Transfer method 1: XMODEM `.COM`

Best for larger SC700/Z180 programs.

On CP/M:

```text
C>XM R NAME.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick the `.COM`, then run:

```text
C>NAME
```

## Transfer method 2: PIP + LOAD HEX paste

Good for smaller programs.

On CP/M:

```text
C>PIP NAME.HEX=CON:
```

Paste the Intel HEX text.

**Critical Tera Term paste settings:**

```text
1 ms per character
1 ms per line
```

Then press `Ctrl+Z`, load, and run:

```text
C>LOAD NAME.HEX
C>NAME
```

## Rebuild from source

Install the **.NET 8 SDK** on Windows, then run:

```powershell
.\scripts\publish-win-x64.ps1
```

Or open:

```text
TMSAsmBuilder.sln
```

The source project targets `net8.0-windows` / WinForms.

## Hardware safety

Some example programs can write to SC719 digital output ports such as `00h`, `01h`, and `02h`. Inspect source before running it on real connected hardware.
