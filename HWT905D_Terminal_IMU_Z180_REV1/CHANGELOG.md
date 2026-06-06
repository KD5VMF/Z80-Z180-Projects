# Changelog

## REV1 - Terminal IMU Display

- Created terminal-only version for systems without LCD1602 or LED I/O boards.
- Removed LCD output on port `00H`.
- Removed pitch LED output on port `01H`.
- Removed roll LED output on port `02H`.
- Removed LCD/HD44780 routines and LED bargraph routines.
- Added ANSI terminal dashboard.
- Added heading, yaw, pitch, roll terminal display.
- Added raw accelerometer X/Y/Z display from packet `55 51`.
- Added raw gyro X/Y/Z display from packet `55 52`.
- Kept angle packet parser for packet `55 53`.
- Kept RomWBW HBIOS serial input and forced `9600 8N1` init.
- Kept serial unit selection keys `0-7`.
- Confirmed working on Small Computer Central SC131, `SCZ180_sc131_std`, Z8S180-K @ 18.432 MHz.

