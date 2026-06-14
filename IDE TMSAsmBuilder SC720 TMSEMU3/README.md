# TMS ASM Builder IDE for SC720 / TMSEMU3

A friendly Windows IDE and build tool for making **Z80 / Z180 CP/M `.COM` programs** that use the **TMS9918A / TMSEMU3 video card** on Small Computer Central / RC2014-style systems.

This repo is set up to be easy to share: the Windows IDE source, the assembler tool, the support ASM libraries, the **BALL** sprite demo, docs, and batch files are all included.

## What opens when you start it

The IDE now opens **blank**.

That is intentional. Nothing is loaded until the user chooses one of these:

- **New ASM** — clears the editor and starts a blank program named `NEWPROG.ASM`.
- **Open ASM** — loads an existing `.ASM` file from disk.
- **Load Ball Demo** — loads the bundled `BALL.ASM` demo.

The old chess/template program has been removed.

## The bundled Ball Demo

`TMSAsmBuilder/Templates/BALL.ASM` is the included demo program.

It builds a CP/M `.COM` and Intel HEX image that:

- probes for the TMS9918A / TMSEMU3 VDP,
- sets a black background,
- enables 16x16 sprites,
- loads four sprite shapes,
- bounces them around the screen using vertical blank timing,
- exits when a CP/M console key is pressed.

The demo includes these support files:

```asm
include "tms.asm"
include "z180.asm"
include "utility.asm"
```

The IDE resolves those from the shared `TMSAsmBuilder/Libs` folder during build.

## What the IDE does

- Edits Z80/TMS9918A assembly in a simple WinForms IDE.
- Starts with an empty editor so users can load or start their own work.
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
- Uses a private temporary build folder so `include "tms.asm"` works without polluting public output folders.
- Creates clean timestamped build/project folders containing only the generated `.ASM` and `.HEX` files.
- Copies the latest `.COM`, `.ASM`, and `.HEX` into `TMSAsmBuilder/Out` for fast transfer.

## Hardware target

This was made for this kind of setup:

- Small Computer Central / RC2014-style Z80 or Z180 machine
- SC720 / SC7xx-style system running RomWBW CP/M
- TMSEMU3 or J.B. Langston-style TMS9918A video card
- Windows PC used as the build/transfer machine
- Tera Term or similar serial terminal for file transfer

## Repository layout

```text
.
├─ TMSAsmBuilder.sln
├─ TMSAsmBuilder/
│  ├─ MainForm.cs                 IDE and builder logic
│  ├─ Program.cs                  WinForms entry point
│  ├─ Assets/                     IDE icon
│  ├─ Libs/                       shared ASM support libraries
│  ├─ Templates/                  BALL.ASM demo template
│  ├─ Tools/                      bundled assembler tool
│  ├─ Work/                       working ASM area
│  ├─ Builds/                     timestamped clean ASM + HEX outputs
│  └─ Out/                        latest ASM + COM + HEX output
├─ docs/                          user and developer notes
├─ build_gui.bat                  build the Windows app
├─ run_gui.bat                    run from source
├─ publish_win_x64.bat            make a release folder
└─ FIRST_RUN.bat                  simple first-run helper
```

## Quick start

1. Install the **.NET 8 SDK** or newer on Windows.
2. Download this repository ZIP and extract it.
3. Double-click `FIRST_RUN.bat`.
4. The IDE opens blank.
5. Click **Load Ball Demo**, **Open ASM**, or **New ASM**.
6. Click **Build .COM + .HEX**.
7. Use the files from:
   - `TMSAsmBuilder/Out` for latest `.COM`, `.ASM`, and `.HEX`
   - `TMSAsmBuilder/Builds/<name>_<timestamp>` for clean `.ASM` and `.HEX` project folders

After building the Ball demo, the usual output files are:

```text
BALL.ASM
BALL.COM
BALL.HEX
```

## Run the Ball Demo on CP/M

After transferring the program to the SC720, run it from CP/M:

```text
C>BALL
```

The TMSEMU3/TMS9918A display should show a black background with four colored bouncing sprite shapes.

## Transfer Ball Demo to CP/M using XMODEM

XMODEM is usually the easiest way to send the finished `.COM` file.

On CP/M:

```text
C>XM R BALL.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick this file from the Windows repo folder:

```text
TMSAsmBuilder\Out\BALL.COM
```

When the transfer finishes, run it:

```text
C>BALL
```

## Transfer Ball Demo to the SC720 using Tera Term, PIP, and the HEX file

This method sends the text `.HEX` file over the console using CP/M `PIP`, then converts it into a runnable `.COM` with CP/M `LOAD`.

Use this when XMODEM is not available, or when sending plain text is easier.

### 1. Build the program in the IDE

In Windows:

1. Open the IDE.
2. Click **Load Ball Demo**.
3. Click **Build .COM + .HEX**.
4. Find the generated HEX file here:

```text
TMSAsmBuilder\Out\BALL.HEX
```

### 2. Set Tera Term transmit delay

This is important. Without a delay, the old CP/M machine can miss characters.

In Tera Term:

```text
Setup -> Serial port...
```

Set a small transmit delay such as:

```text
Transmit delay: 5 ms/char
Transmit delay: 50 ms/line
```

Then click **OK**.

### 3. Start PIP receive on the SC720

At the CP/M prompt on the SC720, type:

```text
C>PIP BALL.HEX=CON:
```

CP/M is now waiting for text from the console.

### 4. Send the HEX file from Tera Term

In Tera Term:

```text
File -> Send file...
```

Choose:

```text
TMSAsmBuilder\Out\BALL.HEX
```

Make sure the file is sent as plain text.

Wait until Tera Term finishes sending the file.

### 5. End the PIP transfer

After the file has finished sending, press:

```text
Ctrl-Z
```

That tells CP/M that the console file is finished.

You should return to the CP/M prompt.

### 6. Convert the HEX file into a COM file

Now run CP/M `LOAD`:

```text
C>LOAD BALL
```

This reads `BALL.HEX` and creates:

```text
BALL.COM
```

### 7. Run it

Now run:

```text
C>BALL
```

You should see the Ball demo on the TMSEMU3/HDMI screen.

## PIP + LOAD quick command list

Here is the short version for the SC720 side:

```text
C>PIP BALL.HEX=CON:
```

Send `BALL.HEX` from Tera Term, then press:

```text
Ctrl-Z
```

Then run:

```text
C>LOAD BALL
C>BALL
```

## Build behavior

The IDE uses a temporary internal build folder so include statements work normally:

```asm
include "tms.asm"
include "z180.asm"
include "utility.asm"
```

Public timestamped build folders stay clean and receive only:

```text
PROGRAM.ASM
PROGRAM.HEX
```

The generated `.COM` is copied to `TMSAsmBuilder/Out` for XMODEM transfer, but it is not copied into the clean project/build folders.

## Tools folder

`TMSAsmBuilder/Tools` contains `sjasmplus.exe`.

The IDE calls it with this default argument pattern:

```text
--raw="{out}" "{src}"
```

That makes a raw CP/M `.COM` style binary from an `org 100h` source file. After that, the IDE converts the `.COM` bytes into Intel HEX records starting at address `0100h`.

## Libs folder

`TMSAsmBuilder/Libs` contains the reusable ASM support files used by the demo and by most TMSEMU3/TMS9918A programs:

- `tms.asm` — TMS9918A/TMSEMU3 probing, setup, VRAM write/read helpers, colors, sprite/tile/text helper routines.
- `tmsfont.asm` — font data used by text-mode programs.
- `z180.asm` — Z180 detection and clock/wait timing helpers.
- `utility.asm` — CP/M console/string/key helper routines.
- Extra upstream/example support files are included as useful references.

These files came from J.B. Langston’s TMS9918A project for RC2014/SC1xx-style Z80/Z180 systems. This repo keeps them in one shared folder instead of copying them into every new project output.

## Third-party code and tools

This project includes support files and tooling so a user can get started quickly:

- `sjasmplus.exe` is bundled in `TMSAsmBuilder/Tools`.
- J.B. Langston TMS9918A/Z180/utility ASM support files are bundled in `TMSAsmBuilder/Libs`.

See `THIRD_PARTY_NOTICES.md` for license and attribution details.

## Status

Current repo package: **REV5 Ball Demo GitHub-ready package**

Main REV5 changes:

- App opens blank with no code loaded.
- Old chess template removed.
- `Load Ball Demo` button added.
- Bundled `BALL.ASM` sprite demo added.
- Project file now copies `Assets`, `Libs`, `Templates`, and `Tools` into build/publish output.
- Docs rewritten around the actual tool, bundled assembler, library files, and CP/M transfer.

## License

Project wrapper/IDE code in this repository is released under the MIT License unless noted otherwise.

Bundled third-party code/tools keep their original licenses. See `THIRD_PARTY_NOTICES.md`.
