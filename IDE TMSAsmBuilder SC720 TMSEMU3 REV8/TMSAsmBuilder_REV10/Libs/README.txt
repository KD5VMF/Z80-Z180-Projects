Libs folder - REV10
==================

Shared ASM support files live here. Demo/user programs include them by name:

  include "tms.asm"
  include "z180.asm"
  include "utility.asm"

REV10 also adds SC700 helper libraries for the user's current hardware:

  include "romwbw.asm"          ; RomWBW HBIOS helpers, including RTC time read
  include "sc700.asm"           ; SC719 ports 00h/01h/02h helpers and LED bars
  include "lcd1602_sc719.asm"   ; optional LCD1602 driver using the proven LCD CLOCK wiring
  include "math8.asm"           ; tiny random/hex/bar/math helpers

Important original files:
  tms.asm       TMS9918A/TMSEMU3 probe, setup, color, VRAM, sprite, tile, and text helpers.
  tmsfont.asm   Font data for text-mode programs.
  z180.asm      Z180 detection, clock, and TMS wait timing helpers.
  utility.asm   CP/M BDOS console, string, key, and small utility helpers.

Original compatibility wrappers/examples:
  tmsc.asm      z88dk wrapper for tms.asm.
  z180c.asm     z88dk wrapper for z180.asm.
  ascii.asm     Original ASCII table example program.

REV10 added files:
  romwbw.asm
    Defines HBIOS_INVOKE=0FFF0h and HBIOS_RTC_GETTIME=020h.
    HbiosRtcGetTime expects HL to point at a six-byte buffer and reads:
      YY MM DD HH MM SS, packed BCD.
    Also includes BCD-to-binary and BCD-to-ASCII helpers.

  sc700.asm
    Defines SC719_PORT0=00h, SC719_PORT1=01h, SC719_PORT2=02h.
    Adds Sc719ReadPorts, Sc719WriteABC, Sc719AllOff, and LED bar helpers.
    Safety: define SC719_WRITE_ENABLE equ 0 before include to make write helpers return without changing outputs.

  lcd1602_sc719.asm
    Optional LCD1602/HD44780 driver for the working LCD CLOCK wiring:
      bit2=RS, bit3=E, bit4=D4, bit5=D5, bit6=D6, bit7=D7, RW=GND.
    Default LCD_PORT is 00h. Define LCD_PORT before include to move it.

  math8.asm
    Small reusable helpers: MathRand8, MathAbs8, MathIncDecDigit, MathHexNibble, MathBar8.

Build behavior in REV10:
  The IDE copies these libs into a private temporary build folder so sjasmplus can resolve include statements.
  Timestamped public build folders now get the generated .ASM, .HEX, and .COM files together.
  Out still receives the latest mirror .ASM and .HEX for convenience.
