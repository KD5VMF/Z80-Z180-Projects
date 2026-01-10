# SC720 LCD Prime Display (8080 assembly)

This repo contains **two** prime-number display programs for your **SC720 Z80 board** using the same **SC719/SC720 4-bit LCD latch** interface as your working clock demo.

- **LCDPRIME16**: 16-bit primes (2..65535)
- **LCDPRIME24**: 24-bit primes (2..16,777,215)
- **LCDCLK**: your reference LCD/RTC clock demo (included as a known-good LCD driver example)

## What the prime demos do

- Start at **2** and compute primes with **exact trial division** (no probabilistic tricks).
- Always print at **row 1, column 0** (top-left).
- Each new prime **overwrites** the previous one (it does *not* march across the display).
- After printing, the code pads spaces out to column 15 so longer/shorter numbers don’t leave junk.
- A single speed knob controls the delay between primes.

Speed knob location in the 16-bit version: `PRIME_DELAY_OUTER EQU ...` in `src/LCDPRIME16.ASM`.  
(See lines 32–40 in the source.)  

## Files

```
src/   Source code
hex/   Intel HEX images
bin/   CP/M .COM binaries (generated from the HEX)
docs/  Notes
tools/ Small helper scripts
```

## Hardware assumptions

The latch mapping is the one used in your LCD clock demo:

- `PORT_LCD` default `00h`
- bit2 = RS, bit3 = E, bits4-7 = D4-D7, R/W tied LOW (write-only)

See `docs/HARDWARE.md`.

## Running (common options)

### Option A: CP/M

1. Copy `bin/LCDPRIME16.COM` (or `bin/LCDPRIME24.COM`) onto your CP/M disk.
2. Run it:

```
A>LCDPRIME16
```

If you prefer converting from HEX on-target, CP/M `LOAD` can be used on many systems:

```
A>LOAD LCDPRIME16
A>LCDPRIME16
```

### Option B: ROM monitor / direct RAM load

- Load the HEX at its recorded addresses (starts at `0100h`)
- Jump to `0100h` (whatever your monitor uses: `G 0100`, `GO 0100`, etc.)

## Tuning the speed

Edit just **one value**:

- `PRIME_DELAY_OUTER` (smaller = faster, larger = slower)

In `src/LCDPRIME16.ASM`, that constant is explicitly marked as “CHANGE THIS (main knob)”.

## Credits

- `src/LCDCLK.ASM` is the LCD/RTC example used as the known-good LCD driver baseline.
