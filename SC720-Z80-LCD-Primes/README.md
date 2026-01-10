# SC720 Z80 LCD Primes (Z80‑native, exact primes)

This project is a **Z80‑native** prime‑number demo for the **SC720 Z80 board** that prints **one prime at a time**
to a **16×2 HD44780 LCD** using the SC719/SC720‑style **4‑bit latch** interface.

**What you’ll see**
- Starts at **2**
- Finds the next prime and prints it at **row 1, column 0** (top‑left)
- Each new prime **overwrites** the previous one (it does **not** march across the LCD)
- Pads spaces to the end of the row so old digits never remain
- Runs forever

---

## Why a Z80 version can be “better” than 8080 (on SC720)

The **Z80 is a superset of the 8080**: most 8080 programs assemble/run on a Z80 unchanged, but the Z80 adds features
that make code **smaller, faster, and easier to write**.

For this project, Z80‑native code is “better” mainly because it can do the same job with:
- **Shorter branches** (`JR`) instead of long absolute jumps everywhere
- **Tight counted loops** (`DJNZ`) for delays and output loops
- **Real 16‑bit subtract/compare** (`SBC HL,DE`) which the 8080 simply doesn’t have
- **Bit test** (`BIT`) without destroying the value you’re checking

In other words:
- If you want **maximum portability** (8080/8085/Z80): write 8080 style.
- If you want **best code for SC720 (Z80)**: write Z80 style (this repo).

---

## Z80 upgrades you’ll actually notice (quick tour)

Here are the Z80 additions that matter most in “real programs”, and how this project uses them.

### 1) `JR` — short relative jumps
**8080:** mostly uses `JMP addr` / `JZ addr` (absolute, 3 bytes).  
**Z80:** adds `JR cc,disp` (relative, 2 bytes), perfect for tight loops and local branches.

**In this program:** used everywhere for local flow control (prime loop, math loops, LCD routines).

### 2) `DJNZ` — decrement B and jump if not zero
This is one of the most useful Z80 instructions for tiny demos.

- `DJNZ label` does: `B = B - 1; if B != 0: jump label`
- It replaces 2–3 instructions on 8080 and makes loops compact and fast.

**In this program:** delay loops, “print N characters” loops, nibble‑pulsing delays, etc.

### 3) `SBC HL,DE` — true 16‑bit subtraction with carry
**8080:** no instruction to subtract 16‑bit registers directly.  
**Z80:** `SBC HL,DE` gives you real 16‑bit subtract/compare logic.

**In this program:** used in the decimal conversion helper (repeated subtraction per digit).

### 4) `BIT b,r` — test a bit without changing the register
**8080:** you often `MOV A,r` then `ANI` (which destroys A and needs restore).  
**Z80:** `BIT 0,L` checks “even/odd” without disturbing the value.

**In this program:** fast even‑check of the candidate number.

### 5) `RL r` + 16‑bit shifts (`ADD HL,HL`)
The Z80 makes bit‑level math cleaner.

**In this program:** the exact remainder helper shifts the dividend and remainder bit‑by‑bit using:
- `ADD HL,HL` (shift dividend left)
- `RL E` / `RL D` (shift remainder left through carry)

---

## How the prime test works (and why it’s accurate)

This is **not** a probabilistic test. It is **exact trial division**.

### Candidate generation
- Starts at `2`
- Then goes to `3`
- Then adds `2` each time (skips all evens)

### Divisor loop
- Tests odd divisors `d = 3, 5, 7, ...`
- Stops when `d*d > n` (correct stopping rule)
- If `n mod d == 0`, it’s composite

### Why it’s fast enough in 16‑bit
For 16‑bit numbers, the largest square root is:

- `sqrt(65535) < 256`

So the divisor fits in **8 bits**, and the loop is bounded (it won’t run forever).

### Exact remainder (no “approximate division”)
The remainder is computed with a small bit‑wise restoring division routine (`MOD16BY8`), so the divisibility check is exact.

---

## LCD interface (SC719/SC720 4‑bit latch)

This code assumes your known‑good SC719/SC720 latch mapping:

- `PORT_LCD` is the LCD control/data latch (default `00h`)
- `bit2` = RS (0 = command, 1 = data)
- `bit3` = E  (enable pulse)
- `bit4..bit7` = D4..D7 (4‑bit data bus)
- R/W tied LOW (write‑only)

If your SC720 LCD demo works with `PORT_LCD EQU 00h`, this program should too.

---

## Speed knob (easy)

Open `src/Z80-LCD-Primes.asm` and change:

```asm
PRIME_DELAY_OUTER   EQU     01H    ; smaller = faster, larger = slower
```

Suggested starting points:
- `01h` = very fast
- `02h..04h` = still fast but easier to read
- `08h+` = slower

---

## Building in OshonSoft Z80 Simulator IDE (v14.91)

This repo is compatible with:

- **OshonSoft Z80 Simulator IDE v14.91**
- Author: **Vladimir Soso**

Official site (reference):

```text
https://www.oshonsoft.com/
```

Steps:
1. Open `src/Z80-LCD-Primes.asm`
2. Assemble / Build
3. You’ll get:
   - `build/Z80-LCD-Primes.hex` (Intel HEX)
   - `build/Z80-LCD-Primes.lst` (listing)

(Those outputs are already included in this repo.)

---

## Loading on the real SC720 board (using your monitor “LOAD”)

Typical flow (exact words vary by monitor, but the idea is always the same):

1. Connect via serial terminal to the SC720.
2. At the monitor prompt, enter the loader command (commonly `LOAD`).
3. Send `build/Z80-LCD-Primes.hex` as **plain text** (ASCII) to the serial port.
4. When the loader finishes, start the program at **0100h** (because `ORG 0100h`):
   - Common commands: `G 0100` or `GO 0100`

---

## Troubleshooting

### LCD backlight on but no characters
- Contrast pot is the #1 cause (turn it until boxes/characters appear).
- Verify `PORT_LCD` matches your latch port.
- If you have a known-good LCD demo, run it first to confirm hardware.

### Garbage characters / unstable display
- Increase delays (especially after init and clear).
- Confirm R/W is tied low and that E/RS lines match the mapping above.

### Digits “stick” when number of digits changes
This program pads the rest of the row with spaces after printing the number, so you should *not* see this.
If you do, confirm you’re running this Z80 version and not an older build.

---

## License
MIT License (see `LICENSE`).
