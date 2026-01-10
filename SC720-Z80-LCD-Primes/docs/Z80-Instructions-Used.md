# Z80 instructions used (quick notes)

This project is intentionally **Z80-native**. The logic is still “8080-flavored”, but it uses a few Z80-only
instructions to keep the code smaller and faster.

## JR (relative jumps)
- `JR Z,label`, `JR NZ,label`, `JR C,label`
- Short, fast, 8-bit signed offset jumps (good for tight loops)

## DJNZ (decrement B and jump if not zero)
- `DJNZ label`
- Decrements `B`. If `B != 0`, jumps to `label`.
- Used heavily in delay loops and “print N chars” loops.

## SBC HL,DE (16-bit subtract with carry)
- `SBC HL,DE`
- Subtracts `DE` from `HL` (plus carry). Great for “compare/subtract until negative” loops.
- Used in the decimal conversion helper.

## OUT (n),A (Z80 port syntax)
- `OUT (PORT_LCD),A`
- Z80 syntax with parentheses around the port constant.

## RL r (rotate left through carry)
- `RL E`, `RL D`
- Used in the small 16-bit math helper (bit-by-bit division/remainder style logic).
