Libs folder
===========

Shared ASM support files live here. Demo/user programs can include them by name:

  include "tms.asm"
  include "z180.asm"
  include "utility.asm"

Important files:
  tms.asm       TMS9918A/TMSEMU3 probe, setup, color, VRAM, sprite, tile, and text helpers.
  tmsfont.asm   Font data for text-mode programs.
  z180.asm      Z180 detection, clock, and TMS wait timing helpers.
  utility.asm   CP/M BDOS console, string, key, and small utility helpers.

The IDE copies these files only into a private temporary build folder so sjasmplus can resolve include statements.
Timestamped public build folders get only the generated .ASM and .HEX files.
