# Changelog

## REV3S

- Stripped source release for real CP/M editing.
- Removed comments and extra blank lines from the ASM file.
- Kept the same terminal-only BBS-style dashboard features from REV3.
- Added separate documentation files so the source can stay small while GitHub remains readable.

## REV3

- Added ANSI color / old BBS-style terminal display.
- Added max G tracking for each direction: `+X`, `-X`, `+Y`, `-Y`, `+Z`, `-Z`.
- Added max magnetic tracking for each direction: `+X`, `-X`, `+Y`, `-Y`, `+Z`, `-Z`.
- Added `R` key to reset all max readings.

## REV2

- Added max G and magnetic field tracking.
- Added magnetic packet parsing.

## REV1 terminal

- Removed LCD and LED board requirements.
- Terminal-only output through CP/M console.
- Used RomWBW HBIOS serial input at 9600 8N1.
