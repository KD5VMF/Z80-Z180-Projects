# Ports and Code Notes

## Source type

`HWTTERM3S.ASM` is written in CP/M `ASM.COM` compatible 8080 mnemonic style. It runs on Z80 and Z180 systems because Z80/Z180 CPUs are compatible with the 8080 instruction set.

That means the source uses instructions like:

```asm
LXI H,0000H
MVI A,001H
CALL ROUTIN
```

instead of modern Z80 syntax like:

```asm
LD HL,0000H
LD A,01H
CALL ROUTIN
```

## Normal hardware output ports removed

This terminal version does not drive the LCD or LED hardware ports used in earlier versions.

Removed from this branch:

| Old port | Old use | Status in terminal version |
|---|---|---|
| `00H` | LCD1602 / SC719 LCD latch | Removed |
| `01H` | Pitch LED bar | Removed |
| `02H` | Roll LED bar | Removed |

## Serial input

The sensor is read through RomWBW HBIOS serial calls, not direct Z180 register polling.

The program defaults to HBIOS serial unit `1`, but keys `0` through `7` can select other HBIOS serial units.

The program initializes the selected HBIOS serial unit to:

```text
9600 8N1
```

The constant used in the source is:

```asm
SER960 EQU 0703H
```

## HBIOS calls

The program uses RomWBW HBIOS through `RST 08H` encoded as byte `0CFH`, because that is safe in old ASM.COM source.

Main serial operations:

| Function | Meaning |
|---|---|
| `00H` | serial input byte |
| `02H` | serial input status / bytes pending |
| `04H` | serial initialize |

## HWT905D packets parsed

The program looks for WIT/HWT binary packets beginning with `55H`.

| Packet | Meaning | Used for |
|---|---|---|
| `55 51` | acceleration | raw acceleration and max G per direction |
| `55 52` | gyro | raw gyro display |
| `55 53` | angle | heading, pitch, roll |
| `55 54` | magnetic | raw magnetic field and max magnetic per direction |

Each packet is checked with the standard low-byte checksum before use.

## Max tracking

REV3 tracks max values separately for each signed direction:

```text
+X -X +Y -Y +Z -Z
```

This is done separately for acceleration/G and magnetic field readings.

Press `R` while running to reset all maxes to zero.

## Terminal output

The program uses ANSI escape sequences for:

- cursor home
- clear screen at startup
- color
- old BBS-style layout

During normal updates, it moves the cursor home and redraws fixed lines rather than clearing the entire screen constantly. This reduces blinking on serial terminals.
