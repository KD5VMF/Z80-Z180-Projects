# Changelog

## REV5

- Added 8-bit pitch LED bar output on I/O port `01H`.
- Added 8-bit roll LED bar output on I/O port `02H`.
- LED bars center at near-zero, move left for negative, and right for positive.
- Keeps the tested REV4A LCD layout and corrected pitch/roll mapping.

## REV4A

- Moved the normal heading line one character to the right.
- Final tested LCD layout:

```text
   HDG 123 NE
 P+005 R-002 OK
```

## REV4

- Fixed pitch/roll labels after hardware testing showed they were swapped.
- Kept working RomWBW HBIOS serial code.

## REV3

- Forced selected RomWBW HBIOS serial unit to 9600 8N1.
- Added raw/debug byte display for troubleshooting.
- Confirmed working HWT905D packets.

## REV2

- Switched from direct Z180 ASCI polling to RomWBW HBIOS serial input.

## REV1 / REV1B

- Initial direct serial polling attempts.
- LCD routines proven working.
