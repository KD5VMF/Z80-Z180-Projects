# HWT905D Terminal IMU BBS Dashboard for Z80/Z180

**Program:** `HWTTERM3S.ASM`  
**Revision:** REV3S stripped source release  
**Target:** CP/M / Z-System on Z80 or Z180 RomWBW systems  
**Sensor:** HWT905D TTL serial IMU  
**Display:** ANSI terminal only

This is the terminal-only HWT905D IMU dashboard. It is made for systems that do **not** have the LCD1602 or LED I/O boards installed.

The program reads HWT905D serial packets through RomWBW HBIOS, then draws a smooth old-BBS-style ANSI terminal screen with heading, pitch, roll, accelerometer data, gyroscope data, magnetic field data, and max readings.

## Tested hardware

This stripped REV3S release was tested working on:

- Small Computer Central **SC131**
- RomWBW config: **SCZ180_sc131_std**
- CPU: **Z8S180-K @ 18.432 MHz**
- HWT905D TTL serial sensor
- Z-System / ZSDOS CP/M-compatible environment

## What was removed

This version intentionally removes all hardware output used by the LCD/LED versions:

- No LCD1602 output on port `00H`
- No pitch LED output on port `01H`
- No roll LED output on port `02H`
- No SC719 LCD dependency
- No external LED I/O board dependency
- No normal hardware `OUT` operations for display devices

All display output goes to the terminal through CP/M console output.

## Why the ASM source is stripped

`HWTTERM3S.ASM` is deliberately stripped of comments and extra blank lines because CP/M `ED` can run out of memory or workspace when editing large source files on real vintage systems.

The source is kept compact so it is easier to paste, store, edit, assemble, and keep on small CP/M disks. The explanation of the code is kept in separate Markdown files in this repo, especially:

- `CODE_WALKTHROUGH.md`
- `PORTS_AND_CODE.md`
- `STRIPPED_SOURCE_NOTE.md`

## Build

On CP/M or Z-System:

```text
ASM HWTTERM3S
LOAD HWTTERM3S
HWTTERM3S
```

Optional:

```text
SUBMIT BUILD
```

## Controls

```text
Q   exit to CP/M
R   reset all max G and magnetic readings
0-7 select RomWBW HBIOS serial unit
```

## Serial setup

The program defaults to RomWBW HBIOS serial unit `1` and initializes it to:

```text
9600 baud, 8 data bits, no parity, 1 stop bit
```

The HWT905D TTL sensor used in this project is expected to output WIT/HWT binary packets.

## Terminal display

The terminal dashboard shows:

- Heading and compass direction
- Pitch and roll
- Raw acceleration X/Y/Z
- Raw gyro X/Y/Z
- Raw magnetic field X/Y/Z
- Max G for each direction: `+X`, `-X`, `+Y`, `-Y`, `+Z`, `-Z`
- Max magnetic field for each direction: `+X`, `-X`, `+Y`, `-Y`, `+Z`, `-Z`
- Packet counters
- Recent raw bytes

The screen uses ANSI escape sequences and color for an old BBS look. A VT100/ANSI-capable terminal is recommended.
