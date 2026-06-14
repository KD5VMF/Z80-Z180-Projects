Templates folder
================

The IDE starts blank on purpose. Nothing is loaded into the editor until the user chooses New ASM, Open ASM, or Load Balls Demo.

Current bundled demo:
  BALLS.ASM

BALLS.ASM is the colorful TMSEMU3 / TMS9918A sprite demo. It uses tile mode, a black background, and four 16x16 sprites that bounce around the screen. It includes:
  include "tms.asm"
  include "z180.asm"
  include "utility.asm"

Those include files are resolved from the shared Libs folder during build.
