# SC719/SC720 LCD latch notes

These programs assume the same 4-bit HD44780 interface you already have working
on the SC719/SC720-style I/O board.

## Port and bit mapping (as used by these programs)

- `PORT_LCD` (default `00h`) is the LCD control/data latch.
- `bit2` = RS (0 = command, 1 = data)
- `bit3` = E (enable pulse)
- `bit4..bit7` = D4..D7 (4-bit data bus)
- R/W is tied LOW (write-only)

If your LCD clock demo works without changes, these prime demos should too.
