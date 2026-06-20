TMS ASM Builder IDE for SC720/SC700 + TMSEMU3 - REV9
====================================================

This is the REV9 upgrade of the ready-to-run Windows repo.

Main REV9 change
----------------
Successful builds now place the .COM file in the same timestamped build folder as the .ASM and .HEX files:

  Builds\NAME_YYYYMMDD_HHMMSS\NAME.ASM
  Builds\NAME_YYYYMMDD_HHMMSS\NAME.HEX
  Builds\NAME_YYYYMMDD_HHMMSS\NAME.COM

This makes large Z180 projects easier: build on the PC, then send the .COM with XMODEM.

The Out folder is still useful as a quick mirror for the latest .ASM and .HEX, but the timestamped Builds folder is now the complete per-build package.

REV9 library upgrades
---------------------
The Libs folder still includes the original J.B. Langston-style TMS9918A/Z180 helpers used by the working demos:

  tms.asm
  z180.asm
  utility.asm
  tmsfont.asm

REV9 adds reusable SC700 helper libraries:

  romwbw.asm
    RomWBW HBIOS invoke constants and RTC read helper.
    HbiosRtcGetTime reads six BCD bytes: YY MM DD HH MM SS.

  sc700.asm
    SC719 digital I/O helpers for ports 00h, 01h, and 02h.
    Includes read shadows, safe LED writes, all-off, and LED bar generation.

  lcd1602_sc719.asm
    Optional LCD1602 4-bit driver using the proven LCD CLOCK wiring:
    bit2=RS, bit3=E, bit4-D7=data, RW=GND.

  math8.asm
    Tiny reusable random, hex, decimal digit, absolute value, and LED-bar helpers.

Transfer reminders
------------------
Small HEX paste method:

  C>PIP NAME.HEX=CON:
  paste the HEX with Tera Term delays
  Ctrl+Z
  C>LOAD NAME.HEX
  C>NAME

For Tera Term HEX paste, keep the important delays:

  1 ms per character
  1 ms per line

Large program XMODEM method:

  C>XM R NAME.COM

Then send the .COM from the matching Builds\NAME_... folder using Tera Term XMODEM Send.

Safety for SC719 outputs
------------------------
SC719 output headers are real electrical outputs.  If external hardware is connected, inspect the program first.
Programs using sc700.asm can set this before including it:

  SC719_WRITE_ENABLE: equ 0

That makes the library write helpers return without changing the SC719 outputs.
