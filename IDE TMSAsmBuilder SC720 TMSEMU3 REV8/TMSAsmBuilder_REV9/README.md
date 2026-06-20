# TMSAsmBuilder REV9

**Portable Windows ASM IDE for SC720 / SC700 / Z80-Z180 systems using the TMSEMU3 / TMS9918A video card.**

REV9 is a ready-to-run folder.  It includes the Windows IDE, assembler tool, helper libraries, templates, sample programs, and build/output folders.

## Easy download

Use this link to download only the `TMSAsmBuilder_REV9` folder instead of the whole repository:

[Download TMSAsmBuilder_REV9 folder](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2FKD5VMF%2FZ80-Z180-Projects%2Ftree%2Fmain%2FIDE%2520TMSAsmBuilder%2520SC720%2520TMSEMU3%2520REV8%2FTMSAsmBuilder_REV9)

Main GitHub folder:

[View TMSAsmBuilder_REV9 on GitHub](https://github.com/KD5VMF/Z80-Z180-Projects/tree/main/IDE%20TMSAsmBuilder%20SC720%20TMSEMU3%20REV8/TMSAsmBuilder_REV9)

## What this is

TMSAsmBuilder REV9 makes it easier to write, assemble, and transfer Z80/Z180 CP/M `.COM` programs for systems using the TMSEMU3 / TMS9918A graphics card.

It is meant for projects like:

- SC720 / TMSEMU3 graphics demos
- SC700 Z180 graphics demos
- self-playing games
- RTC dashboards
- SC719 digital I/O LED/output demos
- CP/M `.COM` programs built on a modern Windows PC

## REV9 main upgrade

Older versions copied the final `.COM` mainly to the `Out` folder.

REV9 also places the final `.COM` file inside the same timestamped build folder as the `.ASM` and `.HEX` files:

```text
Builds\NAME_YYYYMMDD_HHMMSS\NAME.ASM
Builds\NAME_YYYYMMDD_HHMMSS\NAME.HEX
Builds\NAME_YYYYMMDD_HHMMSS\NAME.COM
```

That makes every build folder a complete package.  You can keep old builds, compare versions, or send the exact `.COM` that matches the saved source and HEX.

The `Out` folder still contains the latest quick-output files.

## Folder layout

```text
TMSAsmBuilder_REV9/
├─ TMSAsmBuilder.exe              Windows IDE launcher
├─ TMSAsmBuilder.dll              IDE program logic
├─ Tools/
│  └─ sjasmplus.exe               assembler used by the IDE
├─ Libs/
│  ├─ tms.asm                     TMSEMU3 / TMS9918A helper routines
│  ├─ z180.asm                    Z180 helper routines
│  ├─ utility.asm                 CP/M console/string helpers
│  ├─ tmsfont.asm                 optional font/text helpers
│  ├─ sc700.asm                   SC700 / SC719 helper routines
│  ├─ romwbw.asm                  RomWBW HBIOS / RTC helper routines
│  ├─ lcd1602_sc719.asm           optional LCD1602-over-SC719 driver
│  └─ math8.asm                   small math/random/display helpers
├─ Templates/                     starter ASM templates
├─ Work/                          editable demo/source programs
├─ Builds/                        timestamped complete builds
├─ Out/                           latest build output mirror
└─ Assets/                        IDE icon/assets
```

## How to use

1. Download the `TMSAsmBuilder_REV9` folder.
2. Open `TMSAsmBuilder.exe` on Windows.
3. Start a new program or open one from `Work` or `Templates`.
4. Build the program.
5. Find the finished files in the newest folder under `Builds`.

Example build folder:

```text
Builds\BRNXL1_20260619_210000\BRNXL1.ASM
Builds\BRNXL1_20260619_210000\BRNXL1.HEX
Builds\BRNXL1_20260619_210000\BRNXL1.COM
```

## Transfer method 1: small HEX paste

This works well for smaller programs.

On CP/M:

```text
C>PIP NAME.HEX=CON:
```

Paste the Intel HEX text from the IDE or from the `.HEX` file.

Very important Tera Term paste settings:

```text
1 ms per character
1 ms per line
```

Then press `Ctrl+Z` to end the `PIP` input.

Load and run:

```text
C>LOAD NAME.HEX
C>NAME
```

## Transfer method 2: XMODEM `.COM` transfer

This is the best method for larger Z180 programs and bigger games.

On CP/M:

```text
C>XM R NAME.COM
```

In Tera Term:

```text
File -> Transfer -> XMODEM -> Send...
```

Pick the `.COM` file from the matching timestamped `Builds\NAME_...` folder.

Run it:

```text
C>NAME
```

## Notes for SC700 / Z180 users

The SC700 Z180 system is a great target for larger `.COM` programs because XMODEM transfer avoids the practical limits of pasting huge HEX files.

Useful hardware targets:

- TMSEMU3 / TMS9918A video output
- RomWBW HBIOS and RTC services
- SC719 digital I/O cards at ports such as `00h`, `01h`, and `02h`
- SD-backed CP/M storage

## SC719 output safety

SC719 output headers are real electrical outputs.

If you have external hardware connected to an SC719 output header, inspect the source before running programs that write to I/O ports.

Programs using the REV9 `sc700.asm` helper can be made output-safe by setting:

```asm
SC719_WRITE_ENABLE: equ 0
```

That lets the program run without changing SC719 output states.

## Common source style

Most demos use this pattern:

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

        ; program code here

Exit:
        ld      sp,(OldSP)
        rst     0

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        end
```

## Included demo ideas

The `Work` folder may include examples such as:

- bouncing sprite demos
- self-playing Pong
- chess experiments
- SC700 math dashboards
- RTC / RAM diagnostic demos
- Z180 brain / LED-output demos

## Credits

This project brings together a small Windows IDE workflow, `sjasmplus`, TMSEMU3/TMS9918A helper code, Z180 helper code, CP/M transfer methods, and SC700/SC719 experiment helpers to make retro graphics and I/O programming easier.

Huge thanks to the retro-computing community around RC2014/RCBus, RomWBW, Small Computer Central, TMSEMU3, CP/M, and sjasmplus.

## License / use

Use at your own risk on real hardware.  Check I/O addresses and output wiring before running programs that write to hardware ports.
