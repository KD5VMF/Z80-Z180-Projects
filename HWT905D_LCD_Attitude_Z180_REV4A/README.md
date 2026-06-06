# HWT905D LCD Attitude Display for Z80/Z180 CP/M

**Project:** HWT905D TTL IMU to LCD1602 attitude display  
**Final tested source:** `HWTLCD4A.ASM`  
**Target repo:** `KD5VMF/Z80-Z180-Projects`  
**Target machine:** SC722 / Z180 RomWBW / Z-System or CP/M-compatible environment  
**Build tools:** CP/M `ASM.COM` and `LOAD.COM`

This project reads a WIT Motion HWT905D TTL sensor from Serial Port B through RomWBW HBIOS, parses the HWT angle packet, and displays heading, pitch, and roll on a 16x2 LCD.

## Final LCD Display

```text
   HDG 123 NE
 P+005 R-002 OK
```

The top row was intentionally moved right one LCD position during final testing.

## Confirmed Motion Direction

Final REV4A matches the tested sensor orientation:

```text
Lift sensor/nose up     -> P+
Lower sensor/nose down  -> P-
Tilt left               -> R+
Tilt right              -> R-
```

## Hardware Used

### CPU / System Board

This was built and tested for the **SC722 Z180 CPU module** running RomWBW / Z-System / ZSDOS.

The program is written in **8080-style CP/M ASM syntax**, but it runs on a Z80/Z180 because the Z80/Z180 is backward-compatible with 8080 instructions.

### LCD Board

The LCD1602 is connected through the **SC719 digital I/O / LCD header** style wiring used by the other LCD projects in this repo.

LCD latch port used by this program:

```asm
PORTLD  EQU     000H
```

LCD bit mapping:

```text
bit 2 = LCD RS
bit 3 = LCD E
bit 4 = LCD D4
bit 5 = LCD D5
bit 6 = LCD D6
bit 7 = LCD D7
LCD R/W tied to GND
```

### Sensor

Sensor tested:

```text
HWT905D TTL serial version
9600 baud
8 data bits
No parity
1 stop bit
```

Use the TTL sensor, not the RS-232 version, for direct hookup to the TTL serial header.

Typical HWT905D TTL wires:

```text
Red    -> +5V
Black  -> GND
Yellow -> board RX
Green  -> board TX, optional for configuration
```

For this project the program only needs to receive data, so the sensor TX/yellow wire to the board RX is the important signal.

## Serial / HBIOS Details

Earlier direct Z180 ASCI polling did not work reliably for this setup. The working version uses **RomWBW HBIOS serial calls**.

Default selected HBIOS serial unit:

```asm
SELUNI  DB      01H
```

The program initializes the selected HBIOS serial unit to 9600 8N1:

```asm
SER960  EQU     0703H
```

The HBIOS call is made with `RST 08H`, encoded for CP/M ASM as:

```asm
HBCL    DB      0CFH
        RET
```

HBIOS serial functions used:

```text
Function 00H = serial input
Function 02H = serial input status
Function 04H = serial init
```

Runtime keys:

```text
Q   exit to CP/M
0-7 select another HBIOS serial unit, re-init it to 9600, and continue
```

Unit 1 was the tested working unit for the user setup.

## Sensor Packet Parsed

The program searches for WIT/HWT angle packets:

```text
55 53 RollL RollH PitchL PitchH YawL YawH VL VH SUM
```

Final project note: on this physical setup, pitch and roll appeared swapped compared with the obvious LCD labels, so REV4A intentionally displays:

```text
packet field 1 -> PITCH
packet field 2 -> ROLL
packet field 3 -> YAW / HEADING
```

The code uses a simple integer angle conversion:

```text
degrees ~= ABS(raw signed 16-bit value) / 182
```

This avoids floating point and keeps the program small and CP/M ASM-compatible.

## Build on the Board

Copy `HWTLCD4A.ASM` to the CP/M drive, then run:

```text
ASM HWTLCD4A
LOAD HWTLCD4A
HWTLCD4A
```

A good assembly looks like this:

```text
xxxx
005H USE FACTOR
END OF ASSEMBLY
```

The important part is that there are no left-column error letters such as `U`, `E`, or `O`.

## Included Files

```text
HWTLCD4A.ASM          Final tested CP/M ASM source
README.md            Main project explanation
BUILD.SUB            Optional CP/M SUBMIT build helper
CPM_BUILD_STEPS.txt  Step-by-step build commands
WIRING.txt           Sensor and LCD wiring notes
PORTS_AND_CODE.md    Board, port, HBIOS, and code explanation
CHANGELOG.md         Revision history
```

## Project Status

REV4A is the tested working version:

- LCD works.
- Serial/HBIOS receive works.
- HWT905D packet parse works.
- Heading display works.
- Pitch and roll are corrected.
- Top heading row is visually aligned.
