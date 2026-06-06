# HWTCHS3 - CP/M ANSI Computer vs Computer Chess

HWTCHS3 is a CP/M 8080-safe ANSI terminal chess self-play display program.
It was made to look good on a terminal such as Tera Term while staying friendly to old CP/M systems and the CP/M ASM toolchain.

## What it does

- Draws a color ANSI chess board
- Plays computer vs computer automatically
- Updates changed squares instead of redrawing the whole screen
- Runs slower and smoother so it is fun to watch
- Shows move count, side to move, last move, capture/status text, match number, and total wins
- Keeps total wins for White and Black
- Uses keyboard controls while running

## Controls

- `Q` = quit back to CP/M
- `+` = faster
- `-` = slower

## Build on CP/M

Copy `HWTCHS3.ASM` to your CP/M disk, then run:

```text
C>ASM HWTCHS3
C>LOAD HWTCHS3
C>HWTCHS3
```

## System notes

This program is intended to stay inside safe old-system limits:

- CP/M `.COM` style program
- `ORG 0100H`
- 8080-compatible assembly style
- Uses BDOS console calls
- No hardware `OUT` port control
- No hardware switch reads
- ANSI cursor/color sequences for nice terminal output

## Terminal notes

For the best look in Tera Term or another terminal emulator:

- Use ANSI/VT terminal support
- Use a black background
- Use a green/bright color friendly font if desired
- Keep the terminal wide enough for the side status panel

## Included files

```text
HWTCHS3.ASM             Main current version
src/HWTCHS3.ASM         Same current source inside src folder
src/HWTCHS2.ASM         Prior slower no-flash version
src/HWTCHS1.ASM         First chess board/book version
releases/HWTCHS3_single_source.zip
CHANGELOG.md
BUILD_CP_M.txt
NOTES.md
```

## Version

Current version: HWTCHS3
