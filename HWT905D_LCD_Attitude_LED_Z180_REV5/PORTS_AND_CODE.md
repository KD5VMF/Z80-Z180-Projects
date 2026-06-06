# Ports and Code Notes

## I/O ports

```text
00H = SC719-style LCD1602 latch
01H = pitch LED bar output
02H = roll LED bar output
```

## LCD port bit mapping

```text
bit 2 = RS
bit 3 = E
bit 4 = D4
bit 5 = D5
bit 6 = D6
bit 7 = D7
```

The source symbol is:

```asm
PORTLD  EQU     000H
```

## LED output symbols

```asm
PLED    EQU     001H
RLED    EQU     002H
```

## LED pattern map

```text
18H = center / near zero

negative:
08H = small -
04H = medium -
02H = large -
01H = very large -

positive:
10H = small +
20H = medium +
40H = large +
80H = very large +
```

The LED mapping is handled by `MKLED`.

## RomWBW HBIOS serial

The program uses RomWBW HBIOS serial functions through `RST 08H`.

The 8080 byte for `RST 08H` is `CFH`, so the source uses:

```asm
HBCL    DB      0CFH
        RET
```

Serial functions used:

```text
00H = serial input
02H = serial input status
04H = serial init
```

Default HBIOS serial unit:

```asm
SELUNI  DB      01H
```

The user can press `0` through `7` while running to try other HBIOS serial units.

## Serial line setup

The program calls HBIOS INIT for 9600 8N1:

```asm
SER960  EQU     0703H
```

## HWT905D angle packet

The program looks for:

```text
55 53 RollL RollH PitchL PitchH YawL YawH VL VH SUM
```

The checksum is the low 8 bits of the sum of bytes 0 through 9.

## Angle conversion

The real WIT angle conversion is:

```text
signed16 / 32768 * 180
```

The CP/M ASM version uses a simple integer approximation:

```text
degrees ~= abs(raw) / 182
```

This keeps the program small, fast, and simple for ASM.COM.

## Pitch/roll mapping note

During live hardware testing, the user observed the original pitch/roll display labels were swapped for this physical mounting. REV4 and REV5 intentionally display field 1 as pitch and field 2 as roll to match real motion:

```text
Lift up    -> P+
Lower down -> P-
Tilt left  -> R+
Tilt right -> R-
```
