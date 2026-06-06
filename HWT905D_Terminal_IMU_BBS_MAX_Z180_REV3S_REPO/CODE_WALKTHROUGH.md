# Code Walkthrough for `HWTTERM3S.ASM`

The main source is intentionally stripped, so this file explains the structure.

## 1. Startup

The program starts at `ORG 0100H`, like a normal CP/M `.COM` program. It initializes variables, clears counters, hides the cursor, initializes the selected RomWBW HBIOS serial unit to 9600 8N1, flushes old serial bytes, then draws the terminal screen.

## 2. Main loop

The main loop does three things:

1. Poll the selected HBIOS serial unit.
2. Check the keyboard for `Q`, `R`, or serial-unit selection keys.
3. Redraw the screen when enough valid angle packets have arrived or when the data times out.

The redraw rate is deliberately throttled so the terminal screen does not flicker badly.

## 3. Keyboard controls

`Q` exits to CP/M.

`R` resets all max acceleration/G and magnetic readings to zero.

`0` through `7` select a different RomWBW HBIOS serial unit, reinitialize it to 9600 8N1, flush bytes, and continue.

## 4. Serial input

The program does not directly read Z180 ASCI registers. It uses RomWBW HBIOS serial calls so the same program can run on more RomWBW Z80/Z180 systems.

This was important because the LCD/LED version was tied to specific I/O hardware, while this terminal version is meant to work on systems without those boards.

## 5. Packet parser

The parser waits for byte `55H`, then reads the packet type and the remaining data bytes. It calculates the checksum and only accepts packets with a correct checksum.

Recognized packet types:

- `51H`: accelerometer packet
- `52H`: gyroscope packet
- `53H`: angle packet
- `54H`: magnetic packet

## 6. Angle display

The angle packet provides pitch, roll, and yaw style data. This project uses the mapping that was tested with the physical sensor:

- lifting the sensor gives positive pitch
- lowering the sensor gives negative pitch
- tilting left gives positive roll
- tilting right gives negative roll

Yaw is converted into heading degrees and compass direction.

## 7. Max G tracking

The acceleration packet gives signed raw X, Y, and Z acceleration values. The code checks each signed axis and stores max readings separately for:

```text
+X -X +Y -Y +Z -Z
```

The display shows these maxes until `R` resets them.

## 8. Max magnetic tracking

The magnetic packet is handled the same way. Max magnetic readings are stored separately for:

```text
+X -X +Y -Y +Z -Z
```

If magnetic packet counts stay at zero, the sensor may not currently be configured to output magnetic packets.

## 9. Terminal drawing

The program outputs ANSI color and cursor control strings through CP/M console output. It clears the screen once at startup, then uses cursor-home redraws for smoother updates.

This gives a more old-BBS-style live dashboard without depending on LCD/LED boards.
