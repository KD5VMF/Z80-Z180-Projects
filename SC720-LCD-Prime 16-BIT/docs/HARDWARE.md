# SC720 LCD latch mapping

This project assumes the same SC719/SC720-style 4-bit HD44780 latch wiring:

- `PORT_LCD` (default `00h`) is the LCD control/data latch.
- bit2 = RS (0=command, 1=data)
- bit3 = E  (enable pulse)
- bit4..bit7 = D4..D7 (4-bit data bus)
- R/W is tied LOW (write-only)

If your existing SC720 LCD demo works with `PORT_LCD EQU 00h`, this program should too.
