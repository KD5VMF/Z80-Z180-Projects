# Project Notes

HWTCHS3 was made after the HWTTERM3S-style screen output proved that the system could print a clean, attractive terminal display.
The goal was not to build a huge chess engine that would be painful to edit on an old CP/M machine.
The goal was a compact, watchable, computer-vs-computer chess display that fits old-system limits.

Design goals:

- Look good on a terminal.
- Avoid flicker.
- Avoid huge source size.
- Avoid direct hardware dependencies.
- Keep the program easy to assemble with CP/M ASM.
- Keep it safe for older 8080/Z80 CP/M machines.

Known limitation:

- This is a self-play/book-style chess display, not a modern deep chess engine.
- The win counters are displayed as compact hexadecimal-style counters to keep code small.
