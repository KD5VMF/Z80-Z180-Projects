# HWT905D LCD Attitude + LED Bars for Z180 / RomWBW

Final tested project for KD5VMF's Z80/Z180 Projects repo.

This CP/M `.COM` program reads a WIT Motion HWT905D TTL IMU on the Z180 board's serial Port B using RomWBW HBIOS, displays heading/pitch/roll on a 1602 LCD, and drives two 8-bit LED output ports as live pitch and roll bar indicators.

## Final display

```text
   HDG 123 NE
 P+005 R-002 OK
```

## Final motion mapping

```text
Lift nose up    -> P+
Lower nose down -> P-
Tilt left       -> R+
Tilt right      -> R-
```

## LED output behavior

Two output ports are used:

```text
Port 01H = pitch LED bar
Port 02H = roll LED bar
```

The LEDs center at near-zero and move left for negative values, right for positive values.

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

## Hardware used

- Z180 board running RomWBW / Z-System / ZSDOS or CP/M-compatible environment
- SC719-style LCD1602 interface on I/O port `00H`
- HWT905D TTL serial IMU connected to serial Port B
- 8-bit LED I/O board at port `01H` for pitch
- 8-bit LED I/O board at port `02H` for roll

## Software style

This source is written in CP/M `ASM.COM` 8080-style mnemonics so it can be assembled directly on the vintage machine.

It runs on Z80/Z180 because the Z80/Z180 is 8080-compatible. It uses RomWBW HBIOS calls to access serial I/O instead of directly programming the ASCI registers.

## Build

On the CP/M/Z-System machine:

```text
ASM HWTLCD5
LOAD HWTLCD5
HWTLCD5
```

`ASM` should finish with no `U`, `E`, or `O` errors. Then `LOAD` converts the generated `.HEX` file into `.COM`.

## Controls

```text
Q   exit to CP/M
0-7 select RomWBW HBIOS serial unit and re-initialize it to 9600 8N1
```

Default serial unit is `1`.

## Serial settings

The program initializes the selected RomWBW HBIOS serial unit to:

```text
9600 baud
8 data bits
No parity
1 stop bit
```

The line-control value used in the source is:

```asm
SER960  EQU     0703H
```

## Sensor packet

The program looks for the HWT905D angle packet:

```text
55 53 RollL RollH PitchL PitchH YawL YawH VL VH SUM
```

For this physical mounting and project, the displayed pitch/roll fields are intentionally swapped from the original parser so the LCD matches the real-world motion observed during testing.

## Suggested repo folder

```text
HWT905D_LCD_Attitude_LED_Z180
```
