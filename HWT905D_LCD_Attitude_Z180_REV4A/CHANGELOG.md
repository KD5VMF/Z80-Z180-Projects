# Changelog

## REV4A - Final tested version

- Kept the working RomWBW HBIOS serial input method.
- Kept HBIOS serial unit 1 as the default.
- Forced selected serial unit to 9600 8N1.
- Fixed pitch/roll display mapping:
  - lift up -> P+
  - lower down -> P-
  - tilt left -> R+
  - tilt right -> R-
- Moved normal top heading row right one LCD position.
- Final normal display:

```text
   HDG 123 NE
 P+005 R-002 OK
```

## REV4

- Swapped pitch and roll labels after real sensor testing.

## REV3

- Switched from direct Z180 ASCI polling to RomWBW HBIOS serial.
- Added serial unit select keys 0-7.
- Added 9600 baud initialization.
- Added raw byte/debug screen.

## REV2

- Used RomWBW HBIOS serial input.
- Proved bytes were arriving from the selected serial unit.

## REV1 / REV1B

- Initial LCD and packet parser.
- Direct SIO/Z180 ASCI polling attempts.
- LCD hardware and basic program structure proven.
