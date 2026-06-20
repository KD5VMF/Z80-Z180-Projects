Templates folder - REV10
=======================

The IDE starts blank on purpose. Nothing is loaded into the editor until the user chooses New ASM, Open ASM, or Load Balls Demo.

Current bundled demo:
  BALLS.ASM

BALLS.ASM is the colorful TMSEMU3 / TMS9918A sprite demo. It uses tile mode, a black background, and four 16x16 sprites that bounce around the screen. It includes:
  include "tms.asm"
  include "z180.asm"
  include "utility.asm"

REV10 build output:
  Every successful build creates a timestamped folder under Builds.
  That folder now contains all three final transfer/use files:
    NAME.ASM
    NAME.HEX
    NAME.COM

Transfer choices:
  Small programs can still use HEX paste with PIP + LOAD.
  Larger Z180 programs should use XMODEM and the .COM file from the same build folder.

Those include files are resolved from the shared Libs folder during build.
