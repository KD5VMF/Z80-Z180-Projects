# SC720 Z80 LCD Primes (Z80-native)

A small Z80 program for the **SC720 Z80 board** that continuously finds **prime numbers** and displays them on an
HD44780-compatible **16×2 LCD** using the SC719/SC720-style **4-bit latch** interface.

**Behavior**
- Starts at **2**
- Uses **exact trial division** (no shortcuts / no probabilistic tests)
- Prints **one prime at a time** at **row 1, column 0** (top-left)
- Each new prime **overwrites** the previous one (it does *not* print across the screen)
- Pads spaces so leftover digits never remain (e.g., `97 -> 101` won’t leave junk)
- Includes a **single easy “speed knob”** constant you can change

---

## Files

- `src/Z80-LCD-Primes.asm` — source
- `build/Z80-LCD-Primes.hex` — Intel HEX output (ready to send/load)
- `build/Z80-LCD-Primes.lst` — OshonSoft listing output
- `docs/Z80-Instructions-Used.md` — quick notes on Z80-specific instructions used
- `docs/Build-and-Load.md` — how to assemble in OshonSoft and load/run on the SC720

---

## Quick speed adjustment

Open `src/Z80-LCD-Primes.asm` and change:

- `PRIME_DELAY_OUTER` — **smaller = faster**, larger = slower

(Leave `PRIME_DELAY_INNER` alone unless your CPU speed changes a lot.)

---

## License

MIT License — do whatever you want with it. See `LICENSE`.
