# HWT905D Terminal IMU Display for Z80/Z180 RomWBW

**Project:** `HWTTERM1`  
**Revision:** REV1 terminal-only  
**Author / repo:** KD5VMF Z80-Z180 Projects  
**Tested hardware:** Small Computer Central **SC131** using RomWBW config **`SCZ180_sc131_std`**, **Z8S180-K @ 18.432 MHz**

This is the terminal-only version of the HWT905D IMU display project. It is for Z80/Z180 systems that do **not** have the LCD1602 board or LED I/O board installed.

The program reads an HWT905D TTL serial IMU through RomWBW HBIOS serial input, parses WIT/HWT binary packets, and displays a live terminal dashboard with heading, pitch, roll, raw acceleration, raw gyro, packet counters, byte count, and recent received bytes.

## What changed from the LCD/LED versions

Removed completely:

- LCD1602 output on I/O port `00H`
- Pitch LED output on I/O port `01H`
- Roll LED output on I/O port `02H`
- All `OUT` instructions to LCD or LED hardware
- LCD timing/delay routines tied to the HD44780 display
- SC719 LCD dependency
- External LED I/O board dependency

Added/changed:

- ANSI/VT100-style terminal dashboard
- Cursor-home redraw instead of full clear redraw during live updates
- More data shown because terminal has more room than a 16x2 LCD
- Raw accelerometer packet decode, packet type `55 51`
- Raw gyro packet decode, packet type `55 52`
- Angle/heading packet decode, packet type `55 53`
- HWT905D serial forced to `9600 8N1` through RomWBW HBIOS

## Build on CP/M / Z-System

Copy `HWTTERM1.ASM` to your CP/M drive, then run:

```text
ASM HWTTERM1
LOAD HWTTERM1
HWTTERM1
```

A good assembly shows no `U`, `E`, or `O` errors.

## Runtime controls

```text
Q     exit to CP/M
0-7   select RomWBW HBIOS serial unit and re-init to 9600 8N1
```

Default serial unit is **1**, matching the tested setup.

## Terminal requirements

Use a terminal that understands common ANSI/VT100 escape sequences. The program uses cursor-home redraw so the screen does not blink badly.

Tested with a normal terminal connection to a RomWBW/Z-System SC131.

## Sensor

HWT905D TTL serial IMU.

Expected packet stream includes:

```text
55 51 ... checksum    accelerometer
55 52 ... checksum    gyro
55 53 ... checksum    roll/pitch/yaw angle packet
```

The program uses the same pitch/roll mapping that was verified on the LCD version:

```text
Lift nose up    -> Pitch +
Lower nose down -> Pitch -
Tilt left       -> Roll +
Tilt right      -> Roll -
```

## Notes

This source is written in **CP/M ASM.COM 8080-style mnemonics** so it can build directly on the vintage system with `ASM.COM` and `LOAD.COM`. It runs on Z80/Z180 because the Z80/Z180 is compatible with the 8080 instruction set.

