# TMS ASM Builder IDE for SC720 / TMSEMU3

**TMS ASM Builder IDE** is a friendly Windows IDE for building **Z80/Z180 RomWBW CP/M `.COM` programs** for a Small Computer Central / RC2014-style computer with a **TMSEMU3 or TMS9918A-compatible video card**.

The goal is simple: write or paste one `.ASM` file on a modern Windows PC, click **Build .COM + .HEX**, then move the result to CP/M with XMODEM or paste-ready Intel HEX.

This repo is designed so a new retro-computer user does not have to hunt around for the basic pieces. It includes the Windows IDE source, a portable app folder, the bundled `sjasmplus.exe` assembler, the support ASM library folder, the `BALLS.ASM` TMSEMU3 sprite demo, documentation, and a new `HELP` folder written as a full manual.

## What is new in REV8

REV8 is the **GitHub/help package** release.

- Added a full top-level **`HELP/`** folder.
- Added a full user manual for running the IDE, building code, and transferring files to CP/M.
- Added a copy/paste **ChatGPT device brief** so people can ask ChatGPT for code that fits this exact system.
- Added a deeper ASM guide for writing `org 100h` CP/M programs that use the bundled TMS9918A/TMSEMU3 libraries.
- Added transfer, troubleshooting, repo-sharing, and maintainer notes.
- Added `Portable_Windows_App/` and `RUN_PORTABLE_APP.bat` for users who want to run the already-built IDE from the ZIP.
- Advanced the app revision display to **REV8** while keeping the program name the same.

## Why this exists

Old Z80/Z180 CP/M machines are wonderful, but getting graphics code from a modern PC to a real retro computer can be confusing:

1. You need assembly source that matches the right assembler syntax.
2. You need the TMS9918A/TMSEMU3 library files in the right place.
3. You need a CP/M `.COM` file that starts at `0100h`.
4. You often need Intel HEX too, because sometimes XMODEM is not ready yet.
5. You need transfer steps that work from Tera Term to the real machine.

This IDE ties those pieces together.

## Quick start for normal users

### Easiest path: run the included app

1. Extract the ZIP.
2. Double-click `RUN_PORTABLE_APP.bat`.
3. The IDE opens blank.
4. Click **Load Balls Demo**.
5. Click **Build .COM + .HEX**.
6. Use **Copy HEX** or transfer `Portable_Windows_App/Out/BALLS.COM` by XMODEM.

If Windows says the .NET Desktop Runtime is missing, install the .NET 8 Desktop Runtime or .NET 8 SDK from Microsoft:

```text
https://dotnet.microsoft.com/en-us/download/dotnet/8.0
```

### Developer/source path

1. Install the .NET 8 SDK or newer.
2. Extract the repo.
3. Double-click `FIRST_RUN.bat` or run:

```text
dotnet run --project TMSAsmBuilder/TMSAsmBuilder.csproj
```

## What opens when you start it

The IDE opens **blank**. Nothing is loaded until the user chooses one of these:

- **New ASM** — starts a blank program named `NEWPROG.ASM`.
- **Open ASM** — opens an existing `.ASM` source file.
- **Load Balls Demo** — loads the bundled `BALLS.ASM` TMS9918A/TMSEMU3 sprite demo.

## The bundled Balls demo

`TMSAsmBuilder/Templates/BALLS.ASM` is a real CP/M graphics demo. It builds `BALLS.COM` and `BALLS.HEX`.

It:

- starts at `org 100h`, as normal CP/M `.COM` programs do,
- probes for the TMS9918A/TMSEMU3 VDP,
- adjusts TMS wait timing on fast Z180 machines,
- sets a black screen,
- enables four 16x16 colored sprites,
- bounces them around smoothly,
- exits when a CP/M console key is pressed.

The demo uses:

```asm
include "tms.asm"
include "z180.asm"
include "utility.asm"
```

Those support files live in `TMSAsmBuilder/Libs` and are copied into a private temporary build folder automatically.

## What the IDE does

- Edits Z80/TMS9918A assembly in a dark WinForms editor.
- Starts blank so the user is in control.
- Syntax-highlights comments, labels, opcodes, directives, strings, and numbers.
- Avoids whole-screen editor redraw while typing.
- Builds CP/M `.COM` files with bundled `sjasmplus.exe`.
- Converts the `.COM` bytes into Intel HEX records starting at CP/M address `0100h`.
- Shows paste-ready Intel HEX in the **HEX Paste** tab.
- Has a **Copy HEX** button for Tera Term paste workflows.
- Shows clean colored build logs: green success, yellow/gold warning, red failure/error.
- Keeps build output clean and repeatable.

## IDE buttons

| Button | What it does |
|---|---|
| New ASM | Clears the editor and starts a blank program. |
| Open ASM | Opens an `.ASM` file from disk. |
| Save ASM | Saves the current source. |
| Load Balls Demo | Loads the bundled sprite demo and sets output to `BALLS.COM`. |
| Build .COM + .HEX | Runs the assembler, creates `.COM`, creates `.HEX`, updates the HEX tab, and copies latest output to `Out`. |
| Copy HEX | Copies the full Intel HEX text from the HEX tab. |
| Download J.B. Langston Libs | Downloads upstream example ASM files and puts them in `Libs`. The repo already includes the needed files. |
| Import Lib Folder | Copies `.ASM` files from another folder into `Libs`. |
| Open Lib Folder | Opens `Libs` in Explorer. |
| Find sjasmplus.exe | Lets the user point the IDE at another assembler executable. |
| Open Project Folder | Opens the running app/source folder. |
| Open Builds Folder | Opens timestamped build folders. |
| Clear Log | Clears the build log window. |

## Build output folders

The IDE uses a private temp folder for assembly so include files work. Public folders stay clean.

```text
TMSAsmBuilder/Builds/PROGRAM_YYYYMMDD_HHMMSS/
  PROGRAM.ASM
  PROGRAM.HEX

TMSAsmBuilder/Out/
  PROGRAM.ASM
  PROGRAM.COM
  PROGRAM.HEX
```

Use `Out` when you want the latest files fast. Use `Builds` when you want a timestamped archive of the source and HEX from a specific build.

## Transfer to CP/M with XMODEM

On CP/M:

```text
C>XM R BALLS.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick `BALLS.COM` from the IDE `Out` folder. Then run:

```text
C>BALLS
```

## Transfer to CP/M with paste-ready HEX

This is the lifesaver method when XMODEM is not working yet.

On CP/M:

```text
C>PIP BALLS.HEX=CON:
```

In the IDE, build the program, open the **HEX Paste** tab, and click **Copy HEX**. In Tera Term, paste the text or send the `.HEX` file as text. A small transmit delay is recommended:

```text
Setup -> Serial port -> Transmit delay: 5 ms/char and 50 ms/line
```

When the HEX text is finished, press `Ctrl-Z` to end `PIP`, then run:

```text
C>LOAD BALLS
C>BALLS
```

## Repository layout

```text
.
├─ HELP/                         full manual, ChatGPT prompt, transfer guide, troubleshooting
├─ Portable_Windows_App/         already-built Windows app folder from this ZIP
├─ TMSAsmBuilder.sln             Visual Studio / dotnet solution
├─ TMSAsmBuilder/                C# WinForms source and runtime folders
│  ├─ MainForm.cs                IDE and builder logic
│  ├─ Program.cs                 WinForms entry point
│  ├─ Assets/                    IDE icon
│  ├─ Libs/                      shared ASM support libraries
│  ├─ Templates/                 BALLS.ASM demo template
│  ├─ Tools/                     bundled sjasmplus.exe
│  ├─ Work/                      working ASM files and temp build area
│  ├─ Builds/                    timestamped clean ASM + HEX outputs
│  └─ Out/                       latest ASM + COM + HEX output
├─ docs/                         shorter support docs kept from earlier revisions
├─ RUN_PORTABLE_APP.bat          starts the included portable app folder
├─ FIRST_RUN.bat                 source/developer first run helper
├─ build_gui.bat                 builds from source
├─ publish_win_x64.bat           creates a Windows publish folder
└─ THIRD_PARTY_NOTICES.md        credit and license notes
```

## Important third-party projects

- `sjasmplus` is the Z80-family cross assembler bundled in `TMSAsmBuilder/Tools`.
- J.B. Langston's `TMS9918A` project supplies the TMS/Z180/utility ASM support files used by the demo and many programs.
- RomWBW is the common system software environment for many Z80/Z180 retro-computers, including CP/M-style workflows.
- Tera Term is a common Windows serial terminal used to send `.COM` or paste `.HEX` to the real machine.

See `THIRD_PARTY_NOTICES.md` and `HELP/08_CREDITS_AND_LINKS.md`.

## Best file to give ChatGPT

Open this file and copy/paste it into ChatGPT before asking for new graphics programs:

```text
HELP/02_GIVE_THIS_TO_CHATGPT.md

```

'''text
From your webbrowser enter

https://download-directory.github.io/?url=https://github.com/KD5VMF/Z80-Z180-Projects/tree/main/IDE%20TMSAsmBuilder%20SC720%20TMSEMU3%20REV8/TMSAsmBuilder/bin/Debug/net8.0-windows&filename=TMSAsmBuilder_REV8_ready_to_run

This will pacage up the IDE ready to use.

'''

It tells ChatGPT the exact target: SC720/RomWBW CP/M, Z80/Z180, TMSEMU3/TMS9918A, sjasmplus syntax, `org 100h`, bundled library files, and the preferred working style.

## License

The C# IDE wrapper, scripts, templates created for this repo, and documentation are released under the MIT License unless a file says otherwise.

Bundled third-party code and tools keep their original licenses. Preserve their notices when redistributing. See `THIRD_PARTY_NOTICES.md`.
