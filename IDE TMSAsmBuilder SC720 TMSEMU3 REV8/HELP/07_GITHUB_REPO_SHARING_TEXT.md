# GitHub repo sharing text

## Suggested repository name

```text
TMSAsmBuilder_SC720_TMSEMU3
```

## Short description

```text
Windows IDE for building Z80/Z180 RomWBW CP/M .COM and Intel HEX programs for SC720/TMSEMU3/TMS9918A systems.
```

## Topics

```text
z80
z180
cpm
romwbw
rc2014
small-computer-central
sc720
tms9918a
tmsemu3
retrocomputing
sjasmplus
winforms
```

## README intro paragraph

```text
TMS ASM Builder IDE helps retro-computer users build Z80/Z180 CP/M .COM programs for SC720 / RomWBW / TMSEMU3 / TMS9918A systems from a modern Windows PC. It includes a friendly editor, bundled sjasmplus assembler, TMS support libraries, a working BALLS.COM sprite demo, automatic Intel HEX generation, and paste-ready Tera Term workflow notes.
```

## Release title

```text
REV8 - GitHub help/manual package for SC720 TMSEMU3 ASM Builder IDE
```

## Release notes

```text
REV8 turns the IDE into a more complete shareable GitHub package.

New:
- Added full HELP folder with user manual, transfer guide, troubleshooting, credits, maintainer notes, and a ChatGPT copy/paste target brief.
- Added Portable_Windows_App folder for users who want to run the included built app from the ZIP.
- Added RUN_PORTABLE_APP.bat.
- Updated README for repo sharing.
- Kept REV7 IDE behavior: BALLS.COM output, ASM Source tab, HEX Paste tab, Copy HEX button, colored compile logs, and smooth editor coloring.

The IDE builds Z80/Z180 sjasmplus-style CP/M programs using org 100h, then produces both .COM and Intel HEX output for real RomWBW CP/M transfer.
```

## Credit paragraph

```text
This project wraps and simplifies several excellent retro-computing tools and libraries. sjasmplus is used as the Z80-family cross assembler. J.B. Langston's TMS9918A project supplies the TMS9918A/Z180/utility ASM support files used by the included demos. RomWBW/CP/M and Tera Term workflows make it practical to build on a modern PC and run on a real Z80/Z180 system.
```

## What to tell beginners

```text
Start with the included BALLS.ASM demo. Build it. Transfer BALLS.COM with XMODEM, or use the HEX Paste tab and CP/M PIP/LOAD. Once that works, copy HELP/02_GIVE_THIS_TO_CHATGPT.md into ChatGPT and ask for a new single-file ASM program for this exact target.
```
