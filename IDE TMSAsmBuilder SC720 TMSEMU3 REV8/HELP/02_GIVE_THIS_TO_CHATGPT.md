# Copy/paste this into ChatGPT before asking for code

I am using **TMS ASM Builder IDE for SC720 / TMSEMU3**.

Please write code for this exact target and style:

## Target computer

- Small Computer Central / RC2014-style **Z80 or Z180** retro computer.
- Running **RomWBW CP/M** or compatible CP/M 2.2-style environment.
- Program output must be a normal CP/M `.COM` program.
- A `.COM` program loads and starts at address `0100h`, so source must begin with:

```asm
        org     100h
```

## Video target

- TMSEMU3 / TMS9918A-compatible video display.
- Use the included TMS9918A library routines from `tms.asm`.
- Use black background unless I ask otherwise.
- Prefer simple tile/sprite/text modes that are reasonable for a real TMS9918A-class VDP.
- Do not assume a bitmap framebuffer like VGA.
- Do not assume modern graphics hardware.

## Assembler and IDE

- The IDE uses `sjasmplus.exe`, not CP/M `ASM.COM`.
- Use Z80/sjasmplus-style syntax.
- Return one complete `.ASM` source file only unless I ask for more.
- Keep labels simple and CP/M/old-school friendly.
- Use 8.3 output names like `BALLS.COM`, `STARS.COM`, `CLOCK.COM`.
- Avoid long file names inside the source comments/instructions.

## Available library files

These files are available in the IDE `Libs` folder and are copied into the assembler temp folder automatically:

```asm
include "tms.asm"
include "z180.asm"
include "utility.asm"
```

`tmsfont.asm` is also available for text/font programs, but do not include it unless actually needed.

## Known working program structure

Use this style unless there is a good reason not to:

```asm
        org     100h

Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; Detect Z180 and set TMS wait timing safely.
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait

        ; Find the TMS9918A / TMSEMU3 VDP.
        call    TmsProbe
        jp      z,NoTms

        ; Program setup goes here.
        ; Main loop goes here.
        ; Check CP/M console key so the user can exit.

Exit:
        ld      sp,(OldSP)
        ret

NoTms:
        ; Ideally print a short CP/M console error message if utility.asm supports it,
        ; then return cleanly.
        jp      Exit

OldSP:  dw      0

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        ds      128
Stack:
```

## Important style rules

- Preserve and restore the CP/M stack.
- Include an exit path on any console key.
- Do not create endless loops with no way to exit.
- Keep the program small enough for CP/M transient program area.
- Prefer lookup tables and simple integer math over expensive routines.
- Do not write code that requires interrupts unless I specifically ask and the setup is shown.
- Do not use BIOS/BDOS calls unless they are standard CP/M or already wrapped by `utility.asm`.
- If using TMS sprites, keep to TMS9918A limits and avoid impossible modern sprite features.
- If using TMS text/tile modes, remember the TMS9918A is tile/VRAM based, not linear VGA memory.
- Avoid self-modifying code unless absolutely necessary.
- Use comments so an old-computer hobbyist can understand the program.

## What I need back from ChatGPT

Give me:

1. The complete `.ASM` file content.
2. A suggested output name, like `STARS.COM`.
3. A short note telling me which library files are included.
4. Any important assumptions.

Do not give partial patches. Give the whole source file.

## Example request I may make next

Using the target brief above, write a complete `STARS.ASM` program for the IDE. It should build as `STARS.COM`, use the TMSEMU3/TMS9918A screen, show a simple animated starfield on a black background, and exit on any CP/M key.
