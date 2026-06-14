# Full user manual

## 1. What this program is

TMS ASM Builder IDE is a Windows helper program for building old-school CP/M graphics programs on a modern PC.

It targets this style of machine:

- Z80 or Z180 computer.
- RomWBW CP/M or compatible CP/M-style environment.
- Small Computer Central / RC2014-style hardware.
- TMSEMU3 or TMS9918A-compatible video board.
- Serial terminal connection from Windows to the retro machine.

The IDE writes normal text assembly. It then uses `sjasmplus.exe` to build a raw CP/M `.COM` binary. After that, the IDE creates an Intel HEX version of the same program so the user can paste/send it through Tera Term and run CP/M `LOAD`.

## 2. What problem it solves

Without this IDE, a beginner has to solve many separate problems:

- Which assembler syntax do these TMS library files need?
- Where do `tms.asm`, `z180.asm`, and `utility.asm` go?
- How do I get a `.COM` file instead of some other binary format?
- How do I make a `.HEX` file that CP/M `LOAD` understands?
- How do I move files from a Windows PC to a real CP/M machine?
- Why did my build fail, and where is the real error?

This IDE puts those pieces in one place.

## 3. First run

### Run the included app

From the ZIP/repo folder, double-click:

```text
RUN_PORTABLE_APP.bat
```

That starts the already-built IDE from:

```text
Portable_Windows_App/TMSAsmBuilder.exe
```

If Windows says .NET is missing, install the .NET 8 Desktop Runtime or .NET 8 SDK from Microsoft.

### Run from source

Install .NET 8 SDK or newer. Then double-click:

```text
FIRST_RUN.bat
```

or run:

```text
dotnet run --project TMSAsmBuilder/TMSAsmBuilder.csproj
```

## 4. The main window

The top area has buttons and fields. The middle area has two tabs. The bottom area is the build log.

### ASM Source tab

This is the main code editor. It starts blank. You can type code, paste code, open an `.ASM` file, or load the Balls demo.

The editor uses simple syntax coloring:

- green comments,
- teal labels,
- blue opcodes,
- purple assembler directives,
- orange strings,
- light green numbers.

The editor tries not to jump or redraw the full screen while typing.

### HEX Paste tab

After a successful build, this tab is filled with Intel HEX text. This is the text you can paste/send to CP/M using:

```text
PIP PROGRAM.HEX=CON:
LOAD PROGRAM
```

### Build log

The log shows what the builder is doing. It uses color:

- green/bold for success,
- yellow/gold/bold for warnings,
- red/bold for failures and errors,
- blue/bold for section headers.

Failed compiles should be readable here. Read the first red line and the first yellow line first.

## 5. Button-by-button guide

### New ASM

Starts a blank source file. The IDE asks before clearing existing text. The default file is:

```text
TMSAsmBuilder/Work/NEWPROG.ASM
```

The default output is:

```text
NEWPROG.COM
```

### Open ASM

Loads an existing `.ASM` file. The output name is automatically guessed from the source file name.

Example:

```text
CLOCK.ASM -> CLOCK.COM
```

### Save ASM

Saves the current editor text to the file shown in the `ASM file:` box.

### Load Balls Demo

Loads the bundled TMS9918A/TMSEMU3 sprite demo:

```text
TMSAsmBuilder/Templates/BALLS.ASM
```

The output is set to:

```text
BALLS.COM
```

### Build .COM + .HEX

This is the main button. It:

1. Saves the current ASM.
2. Creates a timestamped build folder.
3. Creates a private temp work folder.
4. Copies all `Libs/*.asm` files into the temp folder.
5. Copies the current source into the temp folder.
6. Runs `sjasmplus.exe` using the argument pattern:

```text
--raw="{out}" "{src}"
```

7. Checks for a `.COM` file.
8. Converts the `.COM` bytes into Intel HEX starting at address `0100h`.
9. Puts `.ASM` and `.HEX` in the clean timestamped build folder.
10. Copies the latest `.ASM`, `.COM`, and `.HEX` into `Out`.
11. Loads the `.HEX` text into the HEX Paste tab.

### Copy HEX

Copies the full Intel HEX text from the HEX Paste tab to the Windows clipboard.

Use this after a successful build when you want to paste into Tera Term.

### Download J.B. Langston Libs

Downloads the upstream TMS9918A project ZIP and copies example `.ASM` support files into `Libs`.

The repo already ships with the needed files, so most users do not need this button.

### Import Lib Folder

Lets you select a folder on your PC. The IDE copies every `.ASM` file from that folder into `Libs`.

Use this if you have a newer or modified set of TMS library files.

### Open Lib Folder

Opens the shared library folder in Windows Explorer.

### Find sjasmplus.exe

Lets you point the IDE to another assembler executable. Normally the bundled one in `Tools` is already selected.

### Open Project Folder

Opens the running application/project folder.

### Open Builds Folder

Opens the timestamped build output folder.

### Clear Log

Clears the log window.

## 6. Important fields

### ASM file

The path where the current editor text will be saved before build.

### Output .COM

The CP/M program name. Keep it short and CP/M-friendly.

Good:

```text
BALLS.COM
CLOCK.COM
TMSDEMO.COM
```

Bad:

```text
MY AWESOME LONG PROGRAM NAME.COM
```

CP/M names should be treated like 8.3 names. The IDE sanitizes long/invalid names.

### Assembler

The path to `sjasmplus.exe` or another compatible assembler.

### Args

Default:

```text
--raw="{out}" "{src}"
```

`{out}` is replaced with the temp `.COM` output path.

`{src}` is replaced with the temp `.ASM` source path.

Most users should not change this.

## 7. Output folders explained

### Work

Working files and temporary build files.

```text
TMSAsmBuilder/Work/
```

### Libs

Shared `.ASM` support files.

```text
TMSAsmBuilder/Libs/
```

### Templates

Built-in starter/demo source files.

```text
TMSAsmBuilder/Templates/
```

### Builds

Clean timestamped output folders.

```text
TMSAsmBuilder/Builds/BALLS_20260614_135433/
  BALLS.ASM
  BALLS.HEX
```

These folders intentionally do not receive a copy of the `.COM` file. That keeps them safe as paste/archive folders.

### Out

Latest output files.

```text
TMSAsmBuilder/Out/
  BALLS.ASM
  BALLS.COM
  BALLS.HEX
```

Use this folder for XMODEM transfer.

## 8. How to build the Balls demo

1. Open the IDE.
2. Click **Load Balls Demo**.
3. Confirm `Output .COM` says `BALLS.COM`.
4. Click **Build .COM + .HEX**.
5. Wait for the success message.
6. Use the **HEX Paste** tab or the `Out/BALLS.COM` file.

## 9. How to run on CP/M using XMODEM

On CP/M:

```text
C>XM R BALLS.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Select:

```text
TMSAsmBuilder/Out/BALLS.COM
```

Then run:

```text
C>BALLS
```

## 10. How to run on CP/M using HEX paste

On CP/M:

```text
C>PIP BALLS.HEX=CON:
```

In the IDE:

1. Build the program.
2. Open **HEX Paste** tab.
3. Click **Copy HEX**.

In Tera Term:

1. Paste the copied HEX text, or send the `.HEX` as a text file.
2. Press `Ctrl-Z` when finished.
3. Run:

```text
C>LOAD BALLS
C>BALLS
```

## 11. What to ask ChatGPT for

Do not ask for generic Z80 assembly. Ask for this exact target.

Use:

```text
HELP/02_GIVE_THIS_TO_CHATGPT.md
```

Copy that file into ChatGPT, then ask for the program you want.

Example request:

```text
Using the attached SC720/TMSEMU3 IDE target brief, write a complete single-file sjasmplus Z80 CP/M program named STARS.ASM. It should build as STARS.COM, use TMS tile mode, black background, simple starfield animation, and exit on any CP/M key.
```

## 12. Good source style

A good program for this IDE normally has:

```asm
        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        call    TmsProbe
        jp      z,NoTms

        ; setup graphics here
        ; main loop here

Exit:
        ld      sp,(OldSP)
        ret

NoTms:
        ; print an error or just return
        jp      Exit

OldSP:  dw      0
        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        ds      128
Stack:
```

Exact library routine names depend on what is present in `tms.asm`, but the included Balls demo shows a confirmed working style.

## 13. Safety expectations

This IDE makes files. It does not directly control your CP/M machine. You still transfer and run the program yourself.

For safest testing:

- Start with the Balls demo.
- Transfer with XMODEM if available.
- Use HEX paste if XMODEM is not ready.
- Keep file names short.
- Do not overwrite important CP/M files.
- Test small programs first.

## 14. When something goes wrong

Read `05_TROUBLESHOOTING.md`.

Most build failures are one of these:

- missing `sjasmplus.exe`,
- missing `tms.asm` / `z180.asm` / `utility.asm`,
- source written for CP/M `ASM.COM` instead of sjasmplus/Z80 syntax,
- filename too long,
- bad include path,
- typo in a label or routine name,
- program forgot `org 100h`.
