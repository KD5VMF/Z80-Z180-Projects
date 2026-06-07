HWTLINK37 PYTHAGOREAN TERMINAL BBS NO-BLINK

Files:
  HWTWRK37.ASM  Worker, run first
  HWTCTL37.ASM  Controller, run second

Purpose:
  Two Small Computer Central Z180 RomWBW CP/M systems talk over Port B / HBIOS unit 1.
  Each system uses Port A for its own Tera Term console.
  Terminal only: no LCD code, no LED code, no OUT DAH.

What changed from HWT36:
  - Keeps the working HWTLINK30/HWT36 packet engine.
  - Larger and better lined-up BBS style fixed terminal screen.
  - Draws the screen frame only once.
  - Updates fixed fields only, so it should blink/flicker much less.
  - Runs A^2 + B^2 = C^2 test jobs forever.

Build:
  ASM HWTWRK37
  LOAD HWTWRK37
  ASM HWTCTL37
  LOAD HWTCTL37

Run order:
  1. Run HWTWRK37 first.
  2. Run HWTCTL37 second.

Keys:
  Q quit
  R reset
  I re-init Port B from Port A line settings
  A send/force on controller
