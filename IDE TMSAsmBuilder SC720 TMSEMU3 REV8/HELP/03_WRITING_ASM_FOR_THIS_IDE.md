# Writing ASM for this IDE

## 1. This is not CP/M ASM.COM syntax

The library files in this repo are written for a Z80-style cross assembler. The IDE uses `sjasmplus.exe`.

That means source can use normal Z80 mnemonics like:

```asm
        ld      a,1
        jp      z,Somewhere
        djnz    Loop
```

Do not rewrite these programs into Intel 8080-only `ASM.COM` style unless you are intentionally making a different project.

## 2. Always start at 0100h

CP/M `.COM` programs start at `0100h`.

Use:

```asm
        org     100h
```

The IDE builds a raw `.COM` and makes Intel HEX records starting at `0100h`.

## 3. Keep output names CP/M friendly

Use 8.3 file names.

Good:

```text
BALLS.COM
CLOCK.COM
STARS.COM
SPRITE.COM
```

Avoid spaces and long names.

## 4. Include files

Typical graphics programs use:

```asm
        include "tms.asm"
        include "z180.asm"
        include "utility.asm"
```

The IDE copies all `Libs/*.asm` into the assembler temp folder before build. Because of that, simple include names work.

## 5. Stack handling

A safe CP/M demo saves the old stack and uses its own stack:

```asm
Start:
        ld      (OldSP),sp
        ld      sp,Stack

        ; work here

Exit:
        ld      sp,(OldSP)
        ret

OldSP:  dw      0
        ds      128
Stack:
```

The stack should be after your code and tables. Bigger programs may want more than 128 bytes.

## 6. Z180 wait timing

The included demo uses this pattern:

```asm
        call    z180detect
        ld      e,0
        jp      nz,NoZ180
        call    z180getclk
NoZ180:
        call    TmsSetWait
```

This lets TMS access timing be adjusted for fast Z180 systems.

## 7. Probe for the video chip

Use the TMS probe before trying to write VRAM:

```asm
        call    TmsProbe
        jp      z,NoTms
```

A clean program should not crash if the video board is missing.

## 8. Exit on keypress

A demo that cannot exit is annoying on CP/M. Build an exit check into the main loop.

The exact console helper depends on `utility.asm`. The Balls demo is the best reference for a working key-exit pattern in this repo.

## 9. TMS9918A mental model

The TMS9918A does not work like VGA.

Think in terms of:

- VRAM writes through VDP ports,
- tile/screen name table,
- color table,
- pattern table,
- sprite attribute table,
- sprite pattern table,
- VBlank/status polling.

Do not ask for or write code that expects a linear chunky framebuffer.

## 10. Good demo ideas

These are realistic for this IDE and hardware:

- sprite bounce demo,
- starfield using character/tile updates,
- text-mode status screen,
- color bars,
- random tile animation,
- clock/status display,
- bouncing logo,
- small game-like demos with a few sprites.

## 11. Harder ideas

These may be possible, but should be simplified:

- full bitmap animation,
- many independent objects,
- high-resolution smooth scrolling,
- large trigonometry effects,
- full chess graphics,
- fast filled polygons.

The VDP is fun, but it is a classic tile/sprite chip.

## 12. A minimal source skeleton

```asm
; MYDEMO.ASM
; Build as MYDEMO.COM in TMS ASM Builder IDE.

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

        ; TODO: initialize TMS mode, colors, patterns, sprites.

MainLoop:
        ; TODO: update animation.
        ; TODO: check console key and jump to Exit.
        jp      MainLoop

NoTms:
        ; TODO: optionally print message.

Exit:
        ld      sp,(OldSP)
        ret

OldSP:  dw      0

        include "tms.asm"
        include "z180.asm"
        include "utility.asm"

        ds      128
Stack:
```

Use `Templates/BALLS.ASM` as the practical reference, because it is known to build and run in this IDE setup.
