# Quick Start

## 1. Start the IDE

From the repository folder, double-click:

```text
FIRST_RUN.bat
```

The IDE opens blank by design. No ASM is loaded on startup.

## 2. Choose what to work on

Use one of these buttons:

- **Load Bounce Demo** — loads the bundled `BOUNCE.ASM` sprite demo.
- **Open ASM** — opens an existing assembly file.
- **New ASM** — starts a blank editor named `NEWPROG.ASM`.

## 3. Build the demo

For the bundled demo:

1. Click **Load Bounce Demo**.
2. Confirm the output name is `BOUNCE.COM`.
3. Click **Build .COM + .HEX**.

The IDE will create:

```text
TMSAsmBuilder/Out/BOUNCE.COM
TMSAsmBuilder/Out/BOUNCE.HEX
TMSAsmBuilder/Out/BOUNCE.ASM
```

It also creates a clean timestamped project folder:

```text
TMSAsmBuilder/Builds/BOUNCE_YYYYMMDD_HHMMSS/
```

That clean folder contains only:

```text
BOUNCE.ASM
BOUNCE.HEX
```

The library files are not copied into the clean build folder.

## 4. Run it on CP/M by XMODEM

On the CP/M machine:

```text
C>XM R BOUNCE.COM
C>BOUNCE
```

In Tera Term, send `TMSAsmBuilder/Out/BOUNCE.COM` by XMODEM.

## 5. Run it on CP/M by PIP + LOAD

On the CP/M machine:

```text
C>PIP BOUNCE.HEX=CON:
```

Send `TMSAsmBuilder/Out/BOUNCE.HEX` as a text file from Tera Term. Use a small transmit delay if needed.

Finish the PIP transfer with `Ctrl-Z`, then run:

```text
C>LOAD BOUNCE
C>BOUNCE
```

## What you should see

The Bounce Demo should probe the TMS9918A/TMSEMU3 card, make the screen black, and show four colorful 16x16 sprites bouncing around. Press any CP/M console key to exit.
