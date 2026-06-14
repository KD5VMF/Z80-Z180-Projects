# TMS ASM Builder IDE for SC720 / TMSEMU3

A friendly Windows IDE and build tool for making **Z80 / Z180 CP/M programs** that use the **TMS9918A / TMSEMU3 video card** on Small Computer Central / RC2014-style systems.

This repo is set up to be easy to share: the Windows IDE source, the assembler tool, the support ASM libraries, the **BALL** sprite demo, docs, and batch files are all included.

## What this IDE makes

The IDE makes these project files:

```text
PROGRAM.ASM
PROGRAM.HEX
```

That is intentional.

The `.HEX` file is the important transfer file. It is plain text Intel HEX, so it can be safely sent through Tera Term, pasted into CP/M `ED`, saved on the SC720, then converted into a runnable `.COM` file with CP/M `LOAD`.

The IDE does **not** rely on XMODEM.

The IDE does **not** require sending a binary `.COM` file over the terminal.

The SC720 makes the final `.COM` file from the `.HEX` file:

```text
C>LOAD PROGRAM
```

For the bundled Ball demo:

```text
C>LOAD BALL
C>BALL
```

## What opens when you start it

The IDE opens **blank**.

That is intentional. Nothing is loaded until the user chooses one of these:

- **New ASM** — clears the editor and starts a blank program named `NEWPROG.ASM`.
- **Open ASM** — loads an existing `.ASM` file from disk.
- **Load Ball Demo** — loads the bundled `BALL.ASM` demo.

The old chess/template program has been removed.

## The bundled Ball Demo

`TMSAsmBuilder/Templates/BALL.ASM` is the included demo program.

It builds an Intel HEX image that:

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
- Builds Intel HEX `.HEX` files starting at CP/M load address `0100h`.
- Keeps shared library files in `TMSAsmBuilder/Libs`.
- Uses a private temporary build folder so `include "tms.asm"` works without polluting public output folders.
- Creates clean timestamped build/project folders containing the generated `.ASM` and `.HEX` files.
- Copies the latest `.ASM` and `.HEX` into `TMSAsmBuilder/Out` for fast transfer.

## Hardware target

This was made for this kind of setup:

- Small Computer Central / RC2014-style Z80 or Z180 machine
- SC720 / SC7xx-style system running RomWBW CP/M
- TMSEMU3 or J.B. Langston-style TMS9918A video card
- Windows PC used as the build/transfer machine
- Tera Term or similar serial terminal for plain-text file transfer

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
│  └─ Out/                        latest ASM + HEX output
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
6. Build the program.
7. Use the files from:
   - `TMSAsmBuilder/Out` for latest `.ASM` and `.HEX`
   - `TMSAsmBuilder/Builds/<name>_<timestamp>` for clean `.ASM` and `.HEX` project folders

After building the Ball demo, the usual output files are:

```text
BALL.ASM
BALL.HEX
```

The SC720 will make:

```text
BALL.COM
```

after you run:

```text
C>LOAD BALL
```

## Important transfer note

Do **not** use XMODEM for this project guide.

Do **not** paste a raw `.COM` file into the terminal. A `.COM` file is binary and may contain control characters such as `Ctrl-Z`, so it can be corrupted if sent as console text.

Use the `.HEX` file.

The `.HEX` file is plain text. That is why this IDE makes HEX output. It can be copied, pasted, typed, or sent as a text file through Tera Term.

## Recommended method: paste BALL.HEX into ED, LOAD it, then run it

This is the most reliable method for this project.

### 1. Build the program in the IDE

In Windows:

1. Open the IDE.
2. Click **Load Ball Demo**.
3. Build the program.
4. Find the generated HEX file here:

```text
TMSAsmBuilder\Out\BALL.HEX
```

### 2. Set Tera Term transmit delay to 1 ms and 1 ms

In Tera Term:

```text
Setup -> Serial port...
```

Set:

```text
Transmit delay: 1 ms/char
Transmit delay: 1 ms/line
```

Then click **OK**.

This small delay helps the SC720 keep up while receiving a pasted or sent text file.

### 3. Start ED on the SC720

At the CP/M prompt:

```text
C>ED BALL.HEX
```

You should see the ED prompt:

```text
*
```

### 4. Enter insert mode

At the `*` prompt, type:

```text
I
```

Press Enter.

ED is now waiting for text.

### 5. Send or paste the HEX file from Tera Term

Use either method.

#### Option A: Tera Term Send File

In Tera Term:

```text
File -> Send file...
```

Choose:

```text
TMSAsmBuilder\Out\BALL.HEX
```

Let the whole file send.

#### Option B: Copy and paste

Open `BALL.HEX` in Notepad or another text editor.

Select all text.

Copy it.

Paste it into the Tera Term window.

Let the whole file finish pasting.

### 6. End ED insert mode

After the HEX text is finished, press:

```text
Ctrl-Z
```

That returns you to the ED `*` prompt.

### 7. Save and exit ED

At the ED `*` prompt, type:

```text
E
```

Press Enter.

ED writes `BALL.HEX` to disk and returns to CP/M.

### 8. Convert the HEX file into a COM file

Now run CP/M `LOAD`:

```text
C>LOAD BALL
```

This reads:

```text
BALL.HEX
```

and creates:

```text
BALL.COM
```

### 9. Run it

Now run:

```text
C>BALL
```

You should see the Ball demo on the TMSEMU3/HDMI screen.

## ED + LOAD quick command list

On the SC720:

```text
C>ED BALL.HEX
*I
```

Send or paste `BALL.HEX` from Tera Term.

Then press:

```text
Ctrl-Z
```

At the ED prompt:

```text
*E
```

Then:

```text
C>LOAD BALL
C>BALL
```

## Alternate method: PIP receives the HEX file from the console

Some users may prefer `PIP` instead of `ED`.

At the CP/M prompt:

```text
C>PIP BALL.HEX=CON:
```

Send or paste `BALL.HEX` from Tera Term.

When the file is finished, press:

```text
Ctrl-Z
```

Then:

```text
C>LOAD BALL
C>BALL
```

If PIP is difficult on your setup, use the ED method above.

## Why HEX is used

The SC720 receives terminal text very well.

Intel HEX is text.

That makes HEX a good transfer format for larger programs because it can be moved through the serial console without needing binary file transfer.

The workflow is:

```text
ASM source on Windows
        ↓
IDE builds Intel HEX
        ↓
Tera Term sends/pastes HEX text
        ↓
ED or PIP saves HEX on CP/M
        ↓
LOAD converts HEX into COM
        ↓
Run the COM program
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

## Tools folder

`TMSAsmBuilder/Tools` contains `sjasmplus.exe`.

The IDE uses the assembler internally to turn `org 100h` Z80 source into program bytes, then it writes Intel HEX records starting at CP/M address `0100h`.

The final transfer file for the SC720 is the `.HEX` file.

## Libs folder

`TMSAsmBuilder/Libs` contains the reusable ASM support files used by the demo and by most TMSEMU3/TMS9918A programs:

- `tms.asm` — TMS9918A/TMSEMU3 probing, setup, VRAM write/read helpers, colors, sprite, tile, and text helper routines.
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
- Docs rewritten around the actual tool, bundled assembler, library files, and CP/M text transfer using HEX, ED, PIP, and LOAD.

## License

Project wrapper/IDE code in this repository is released under the MIT License unless noted otherwise.

Bundled third-party code/tools keep their original licenses. See `THIRD_PARTY_NOTICES.md`.
