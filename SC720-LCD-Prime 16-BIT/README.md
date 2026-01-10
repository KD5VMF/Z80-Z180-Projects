# SC720 LCD Prime Display (16-bit, 8080-compatible)

This repo contains **one** program: a **16-bit prime-number display** for the **SC720 Z80 board**
using your SC719/SC720-style **4-bit HD44780 LCD latch** interface.

## What it does

- Computes **prime numbers starting at 2** (exact trial division; not probabilistic)
- Displays **one prime at a time** at **row 1 / column 0** (top-left)
- Each new prime **overwrites** the previous prime (in-place)
- Pads the rest of the LCD row with spaces so old digits don’t remain (e.g. `997` → `1009`)
- Has an easy speed knob: `PRIME_DELAY_OUTER EQU ...` in the source

## Files

```
src/LCDPRIME.ASM     Source
hex/LCDPRIME.HEX     Intel HEX image
bin/LCDPRIME.COM     Flat binary extracted from the HEX (CP/M .COM style)
tools/ihex_to_com.py HEX -> COM converter (optional)
docs/HARDWARE.md     LCD latch mapping notes
```

## Running

### CP/M
Copy `bin/LCDPRIME.COM` to your CP/M disk and run:

```
A>LCDPRIME
```

### Monitor / ROM loader
Load `hex/LCDPRIME.HEX` at its addresses (starts at `0100h`), then jump to `0100h`.

## Speed control

In `src/LCDPRIME.ASM`, edit just this constant:

```asm
PRIME_DELAY_OUTER EQU 06H   ; smaller = faster, larger = slower
```

## HEX -> COM notes

The included `bin/LCDPRIME.COM` was generated from `hex/LCDPRIME.HEX`.
If you regenerate a new HEX, you can recreate a COM with:

```sh
python3 tools/ihex_to_com.py hex/LCDPRIME.HEX bin/LCDPRIME.COM
```

## Build info (generated)

The included COM was extracted from the HEX address range:
- start: `0x100`
- end:   `0x39b`
- size:  668 bytes
