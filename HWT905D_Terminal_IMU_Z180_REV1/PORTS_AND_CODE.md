# Ports and Code Notes

## Direct I/O ports

This terminal-only revision intentionally does **not** write to LCD or LED I/O ports.

Removed from the LCD/LED branch:

| Old use | Old port | REV1 terminal status |
|---|---:|---|
| LCD1602 / SC719 latch | `00H` | removed |
| pitch LED bar | `01H` | removed |
| roll LED bar | `02H` | removed |

There are no LCD/LED `OUT` instructions in `HWTTERM1.ASM`.

## Serial input

Serial input is handled through RomWBW HBIOS instead of direct UART port reads.

Default HBIOS serial unit:

```text
unit 1
```

The program supports runtime unit selection with keys `0` through `7`.

## Baud/config

The selected HBIOS serial unit is initialized to:

```text
9600 baud, 8 data bits, no parity, 1 stop bit
```

The source constant is:

```asm
SER960  EQU     0703H
```

## HBIOS calls used

The program calls HBIOS through `RST 08H`, encoded for ASM.COM as:

```asm
HBCL    DB      0CFH
        RET
```

Serial functions used:

| Function | Meaning |
|---:|---|
| `00H` | serial input/read |
| `02H` | serial input status / bytes pending |
| `04H` | serial init |

## HWT905D packets parsed

The parser searches for WIT/HWT packet frames:

```text
55 TYPE d0 d1 d2 d3 d4 d5 d6 d7 SUM
```

Packet types used:

| Type | Meaning | Displayed data |
|---:|---|---|
| `51H` | acceleration | raw X/Y/Z |
| `52H` | gyro | raw X/Y/Z |
| `53H` | angle | heading/yaw, pitch, roll |

## Pitch / roll mapping

This project keeps the mapping verified on the working LCD version:

```text
packet field 1 -> pitch
packet field 2 -> roll
packet field 3 -> yaw / heading
```

Verified motion:

```text
lift nose up    -> P+
lower nose down -> P-
tilt left       -> R+
tilt right      -> R-
```

## Screen update style

The terminal screen is drawn with ANSI/VT100 escape sequences.

At startup it clears the terminal once. During live updates it sends cursor-home and rewrites the fixed dashboard. This is much less blinky than clearing the whole screen each refresh.

