# Changelog

## HWTLINK37

- Kept the working HWTLINK30/HWT36 packet engine.
- Terminal-only version, with no LCD/LED I/O writes.
- Runs continuous Pythagorean `A^2 + B^2 = C^2` tests.
- Draws the BBS-style terminal frame once and updates fixed fields to reduce blink/flicker.
- Uses proper Controller/Worker naming instead of master/slave.
- Files remain CP/M-friendly 8.3 names: `HWTCTL37.ASM` and `HWTWRK37.ASM`.
