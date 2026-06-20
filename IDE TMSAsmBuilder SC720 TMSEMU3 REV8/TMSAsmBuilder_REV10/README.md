# TMSAsmBuilder REV10 LATEST IDE

**Portable Windows ASM IDE for SC720 / SC700 / Z80-Z180 systems using TMSEMU3 / TMS9918A graphics.**

This is the all-in-one latest **REV10 IDE** package: the compiled IDE is at the top level, and the clean C# source repo is included under `src\TMSAsmBuilder`.

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

REV10 automatically finds `Tools\sjasmplus.exe` and the ASM library folder when they are beside the EXE.

## REV10 upgrades

- **Multithreaded/background build path** so the UI stays responsive while large programs assemble.
- **Cancel Build** button for stopping long builds cleanly.
- **Large ASM loading screen** with a progress bar for files 64 KB and larger.
- **Async open/save** so big files do not make the IDE look dead.
- **Large-file-safe syntax coloring**: normal files still get color; huge files avoid expensive full recolor.
- **Clean portable layout** with tools, libs, templates, work files, source, scripts, docs, output folders, and the EXE all together.
- **REV9 build behavior preserved**: timestamped build folders plus latest `.ASM/.HEX/.COM` mirrored into `Out`.

## Folder layout

```text
TMSAsmBuilder_REV10_LATEST_IDE\
├─ TMSAsmBuilder.exe              Ready-to-run Windows IDE
├─ TMSAsmBuilder.dll/deps/json    Runtime files for the IDE
├─ Assets\                        Icon and UI assets
├─ Tools\                         sjasmplus.exe assembler
├─ Libs\                          TMSEMU3, Z180, SC700, RomWBW helper ASM libs
├─ Templates\                     Starter ASM files
├─ Work\                          Editable demo/source programs
├─ Builds\                        Timestamped build output folders
├─ Out\                           Latest quick-output mirror
├─ src\TMSAsmBuilder\             Clean C# WinForms source
├─ scripts\                       Windows helper scripts
└─ docs\                          Extra notes
```

## Build output

When you press **Build COM+HEX**, REV10 creates a timestamped folder like:

```text
Builds\CHESSX_20260620_153000\CHESSX.ASM
Builds\CHESSX_20260620_153000\CHESSX.HEX
Builds\CHESSX_20260620_153000\CHESSX.COM
```

It also mirrors the newest output to:

```text
Out\CHESSX.ASM
Out\CHESSX.HEX
Out\CHESSX.COM
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
