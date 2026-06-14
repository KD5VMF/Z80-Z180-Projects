# TMS ASM Builder IDE for SC720 / TMSEMU3

**A friendly Windows IDE for building Z80/TMS9918A CP/M programs for the Small Computer Central SC720 and TMSEMU3-style graphics setup.**

This project makes the fun part easier: write or paste Z80 assembly, click **Build .COM + .HEX**, send the Intel HEX file to the Z80, **LOAD IT THEN RUN IT**.

It is built around the working SC720 / RomWBW / CP/M flow:

```text
Windows IDE  ->  sjasmplus  ->  CP/M .COM  ->  Intel HEX  ->  PIP to Z80  ->  LOAD  ->  RUN
```

The big idea is simple: the PC does the modern cross-assembly work, and the SC720 gets a plain CP/M program that starts at `0100h`, just like normal `.COM` programs.

---

## What this repo includes

- Windows C# WinForms IDE project using **.NET 8**.
- ASM editor with simple syntax coloring.
- Builder button that runs `sjasmplus.exe`.
- Automatic `.COM` creation.
- Automatic Intel HEX conversion from the `.COM` bytes.
- Clean timestamped build folders containing only the final `.ASM` and `.HEX`.
- Latest `.COM`, `.ASM`, and `.HEX` copies in `Out` for quick access.
- Shared `Libs` folder for the TMS9918A / Z180 support files.
- Starter templates.
- GitHub-ready docs, credits, transfer instructions, and a Windows build workflow.

---

## Target hardware and software

This was made for this kind of setup:

- **Small Computer Central SC720** or similar RomWBW CP/M Z80/Z180 computer.
- **TMSEMU3** or compatible TMS9918A-style graphics card/module.
- **RomWBW CP/M** with `LOAD.COM` available.
- A terminal program such as **Tera Term** for serial transfer.
- Windows PC for editing/building.

The generated `.COM` programs are normal CP/M transient programs loaded at `0100h`.

---

## Fast start

### 1. Install .NET 8 SDK on the Windows PC

Install the **.NET 8 SDK** from Microsoft if you want to build/run from source.

The normal developer path is:

```text
run_gui.bat
```

or:

```text
dotnet run --project TMSAsmBuilder\TMSAsmBuilder.csproj
```

### 2. Make sure the assembler is present

This repo is set up to use:

```text
TMSAsmBuilder\Tools\sjasmplus.exe
```

If the file is missing, download the Windows release of `sjasmplus` and put `sjasmplus.exe` there.

### 3. Make sure the support ASM libs are present

Typical files in `TMSAsmBuilder\Libs` are:

```text
tms.asm
tmsfont.asm
z180.asm
utility.asm
```

The IDE also has a **Download J.B. Langston Libs** button, but the checked-in repo is meant to be ready to use when those files are included.

### 4. Build a program

1. Start the IDE.
2. Click **New ASM**, **Open ASM**, or **Load Chess Template**.
3. Set the CP/M output name, for example:

```text
PACMAN.COM
```

4. Click **Build .COM + .HEX**.

A clean timestamped folder appears under:

```text
TMSAsmBuilder\Builds
```

That folder contains only:

```text
PACMAN.ASM
PACMAN.HEX
```

The latest `.COM`, `.ASM`, and `.HEX` are also copied to:

```text
TMSAsmBuilder\Out
```

---

## Send HEX to the SC720 and run it

This is the easy safe-text method when XMODEM is not what you want to use.

On CP/M:

```text
C>PIP PACMAN.HEX=CON:
```

In Tera Term:

```text
Setup -> Serial port -> Transmit delay
```

Good starting delay:

```text
5 ms/char
50 ms/line
```

Then:

```text
File -> Send file...
```

Pick the generated `.HEX` file. When it finishes, press:

```text
Ctrl-Z
```

Back at CP/M:

```text
C>LOAD PACMAN
C>PACMAN
```

That is the whole flow: **send HEX, LOAD it, then RUN it**.

---

## XMODEM method

If XMODEM is working on your CP/M system, use the `.COM` file from `Out`.

On CP/M:

```text
C>XM R PACMAN.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick:

```text
TMSAsmBuilder\Out\PACMAN.COM
```

Then run:

```text
C>PACMAN
```

---

## Why this exists

J.B. Langston's TMS9918A examples and support routines are excellent, but they use Z80-style assembler syntax such as:

```asm
ld      hl,TmsFont
jp      z,NoTms
include "tms.asm"
defb    "HELLO",0
```

That is not CP/M `ASM.COM` Intel 8080 syntax. So the nice path is to assemble on the Windows PC using `sjasmplus`, then send the output to the real Z80 machine.

This program wraps that into a simple IDE:

- edit the ASM,
- build with the right include folder,
- make `.COM`,
- make `.HEX`,
- keep the output folders clean,
- give the user exactly what needs to be copied to CP/M.

---

## Intel HEX behavior

The IDE converts raw `.COM` bytes into Intel HEX records starting at:

```text
0100h
```

That is the standard CP/M `.COM` load address.

The HEX output ends with:

```text
:00000001FF
```

CP/M `LOAD` reads the Intel HEX file and writes the matching `.COM` file.

---

## Project layout

```text
TMSAsmBuilder_SC720_TMSEMU3_REV5_GITHUB_REPO/
|
|-- README.md
|-- LICENSE
|-- NOTICE.md
|-- CHANGELOG.md
|-- CONTRIBUTING.md
|-- build_gui.bat
|-- run_gui.bat
|-- publish_portable.bat
|-- get_jblang_examples.ps1
|-- .github/workflows/dotnet-windows.yml
|
|-- docs/
|   |-- BUILD_AND_RUN.md
|   |-- TRANSFER_TO_CPM.md
|   |-- TOOLS_AND_CREDITS.md
|   |-- INTEL_HEX_NOTES.md
|   |-- GITHUB_SETUP.md
|   `-- TROUBLESHOOTING.md
|
`-- TMSAsmBuilder/
    |-- TMSAsmBuilder.csproj
    |-- Program.cs
    |-- MainForm.cs
    |-- Assets/
    |-- Libs/
    |-- Tools/
    |-- Templates/
    |-- Work/
    |-- Out/
    `-- Builds/
```

---

## Important notes for GitHub

- The IDE source is yours to share under the root `LICENSE`.
- Third-party files keep their own copyright/license headers.
- The TMS9918A and Z180 support ASM files are credited to J.B. Langston where applicable.
- The 6x8 font file credits Oleg Kosenkov / raster-fonts in its header.
- `sjasmplus.exe` is a third-party tool; the official project link is in the credits.
- This project is not affiliated with Microsoft, Small Computer Central, RomWBW, J.B. Langston, Tera Term, or the sjasmplus project.

---

## Suggested GitHub description

```text
Windows IDE for building Z80/TMS9918A CP/M programs for SC720/TMSEMU3. Builds .COM and Intel HEX so you can PIP, LOAD, and run on real RomWBW CP/M hardware.
```

Suggested topics:

```text
z80 z180 cpm romwbw sc720 tms9918a tmsemu3 rc2014 sjasmplus intel-hex winforms retrocomputing
```

---

## Credits

This repo is mainly a friendly wrapper around great retro-computing tools and libraries. Please see:

- [`docs/TOOLS_AND_CREDITS.md`](docs/TOOLS_AND_CREDITS.md)
- [`NOTICE.md`](NOTICE.md)

The short version: **this IDE takes advantage of other excellent programs and libraries to make the whole `.ASM -> .COM -> .HEX -> LOAD -> RUN` path easy.**
