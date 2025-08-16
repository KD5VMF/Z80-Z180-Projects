# SC7xx Retro Lab — Z80 / RomWBW (SC722 • SC131 • SC719 • SC794)

- All Written by Chat-GPT5 at the request of KD5VMF

A collection of small-but-fun programs and utilities for the SC7xx family running **RomWBW CP/M**:

- **MBASIC** math demos (primes, totient, Collatz “record hunter”), LED drivers, and visual toys  
- **CamelForth** snippets for faster number crunching and I/O experiments  
- Simple **I/O utilities** for front-panel LEDs and ports  
- **Transfer helpers** (XMODEM) and quick-reference docs

> Tested on **RomWBW HBIOS v3.5.x** with **SC131/SC719**; designed to be portable across **SC722 / SC131 / SC719 / SC794**.  
> CP/M 2.2 conventions throughout (8.3 filenames, uppercase ASCII).

---

## Hardware & Environment

- **Targets:** SC722, SC131, SC719, SC794 (RomWBW)
- **Console:** COM0/COM1 (typical 115200 8N1). Check/change with:
  ```
  MODE
  MODE COM0:115200,N,8,1
  ```
- **Storage:** RAM disk on `B:` (volatile), SD card on `C:` (persistent), others per your build
- **MBASIC:** Microsoft BASIC-80 Rev 5.21 (CP/M)

> **No folders** on CP/M 2.2 (flat filesystem). Organize by drives and (if available) user areas.

---

## Quick Start (CP/M)

Run any MBASIC program:

```text
C:
MBASIC
LOAD "COLLINFO.BAS"
RUN
```

- Save: `SAVE "COLLINFO.BAS"`  
- Exit to CP/M: `SYSTEM`  
- List BASIC files: `DIR *.BAS`

**Serial transfer (XMODEM):**

- Receive PC → SC7xx:
  ```
  XM RK FILENAME.COM      ; waits "Ready to receive..."
  ```
  Then in your PC terminal, **Send via XMODEM-1K (CRC)**.

- Send SC7xx → PC:
  ```
  XM S FILENAME.COM
  ```

---

## LED Port Note

Several programs drive front-panel LEDs. We default to:

```basic
LEDPORT = &H00   ' SC719 typical demo port
```

If your board maps LEDs elsewhere, edit that constant in the source (e.g., `&H80`). The programs update LEDs gently so patterns are visible.

---

## Program Index (MBASIC)

| Program           | Category     | What it does                                                                 | Input/Prompt                       | Screen Output                            | File Output           | LEDs |
|-------------------|--------------|------------------------------------------------------------------------------|------------------------------------|-------------------------------------------|-----------------------|------|
| `LEDLAB10.BAS`    | I/O/Visual   | **LED Math Lab**: 10 distinct patterns + **mode 0 = cycle all**             | Delay; Mode (0–10)                 | Mode banner; returns to menu on **Q**     | —                     | ✔    |
| `COLLINFO.BAS`    | Math/Heavy   | **Collatz Record Hunter** with detailed intro; finds new max **steps/peak** | N (upper limit), save Y/N          | Compact “record” lines + progress         | `COLLSTAT.TXT` (opt.) | ✔    |
| `PRIMELED.BAS`    | Math         | Prime scanner: prints primes, gap, counts                                   | N (upper limit)                    | Prime lines + periodic summary            | `PRIMESTA.TXT`        | ✔    |
| `PRIMEFORE.BAS`   | Math         | Primes forever (numbers only); **Q** quits                                  | —                                  | Just the primes                           | —                     | —    |
| `PRIMEGAP.BAS`    | Math         | Primes ≤ N with **gap** from previous and running **max gap**               | L (limit)                          | Periodic progress every 500 primes        | `PRIMEGAP.TXT`        | —    |
| `TOTIENT.BAS`     | Math/Table   | Euler’s **φ(n)** for 1..N (fast factorization loop)                         | N (limit)                          | Periodic progress                         | `TOTIENT.TXT`         | —    |
| `DIVCLASS.BAS`    | Math/Table   | Sum of proper divisors; classify **Perfect/Abundant/Deficient**             | N (limit)                          | Each n with sum + class; final summary    | —                     | —    |
| `DIVCLASS_SAVE.BAS`| Math/Table  | Same as above, but logs to disk                                             | N (limit)                          | Progress + final summary                  | `DIVCLASS.TXT`        | —    |
| `STARFIELD.BAS`   | Visual       | ANSI/VT100 **starfield** animation; **Q** quits                             | —                                  | Animated starfield                        | —                     | —    |
| `FIBRATIO.BAS`    | Math/Demo    | Fibonacci numbers with running ratio → **golden ratio** (φ)                 | N (terms)                          | Neat 3-column table                       | —                     | —    |
| `LEDDEMO.BAS`     | I/O/Visual   | Random LED patterns at LED port with gentle delay                           | —                                  | “Press Ctrl-C to stop…” banner            | —                     | ✔    |

CSV files are simple “comma-separated-ish”—easy to import into a spreadsheet.

---

## Detailed Program Notes

### `LEDLAB10.BAS` — LED Math Lab (10 patterns + cycle mode)
A menu-driven LED playground for SC7xx front-panel LEDs (default port `&H00`). Pick any of **10** patterns or select **mode 0** to cycle through all of them repeatedly. Press **Q** inside any mode to return to the menu.

- **Inputs:** delay (bigger = slower) and mode (0–10).
- **Patterns:**  
  1. **LFSR-8** — max-length 8-bit LFSR (255-step pseudo-random).  
  2. **Rule-30 CA** — 1-D cellular automaton on an 8-bit ring (wraparound).  
  3. **Logistic map** — `x → 4x(1−x)` in fixed-point 0..255; chaotic.  
  4. **Counter** — binary up counter (0..255 wrap).  
  5. **RotRing** — rotating one-hot ring (bit marches left, wraps).  
  6. **KITT** — bouncing one-hot scanner (back-and-forth).  
  7. **Sparkle** — decay + random spark bits (twinkling).  
  8. **Rule-110 CA** — another classic cellular automaton.  
  9. **BitReverse** — counter displayed with bit-reversal.  
  10. **DualRing** — two one-hot rings in opposite directions.  
- **Mode 0 (Cycle):** Asks for steps per pattern (default 256), runs 1→10, loops forever until **Q**.
- **LED port:** change `LEDPORT = &H..` near the top if your LEDs use a different I/O address.

### `COLLINFO.BAS` — Collatz Record Hunter (LEDs + optional logging)
- **What it does:** Scans `1..N`. For each `n`, applies: even → `n := n/2`, odd → `n := 3*n + 1`. Tracks **steps** and **peak** value for the chain.
- **Records printed:** `[NEW_MAX_STEPS]`, `[NEW_MAX_PEAK]` (or both).
- **Screen (fixed-width):** `n=… s=… p=… a=… avg=… [RECORD]`
- **LEDs:** low byte of the current chain value (update ~every 8 steps).
- **Prompts:** N (0 = very high), save Y/N → `COLLSTAT.TXT` if Y.
- **Stop:** `Ctrl-C`.

### `PRIMELED.BAS` — Primes + LED mirror + stats file
- Prime, **gap** from previous, **count**.  
- LEDs mirror low byte of prime.  
- Writes `PRIMESTA.TXT` (`prime,gap,count,maxgap`).

### `PRIMEFORE.BAS` — Primes forever (numbers only)
- Sqrt trial division over odd candidates.  
- Quit with `Q`.

### `PRIMEGAP.BAS` — Prime & gap table to L
- Finds primes ≤ `L` and logs `prime, gap, running_max_gap` → `PRIMEGAP.TXT`.  
- Progress printed every 500 primes.

### `TOTIENT.BAS` — Euler’s φ(n) table 1..N
- Computes φ(n) using the product formula (factor by distinct primes).  
- Writes `n,phi(n),phi(n)/n` to `TOTIENT.TXT`; shows running max and final sum.

### `DIVCLASS.BAS` — Perfect / Abundant / Deficient
- Proper-divisor sum per `n`; classifies; prints periodic counts and final tallies.

### `DIVCLASS_SAVE.BAS` — Same, with logging
- Writes `DIVCLASS.TXT` (`n,sum_proper_divisors,kind`) and prints the same summaries.

### `STARFIELD.BAS` — ANSI/VT100 starfield
- Needs ANSI/VT100 terminal; `Q` to quit.

### `FIBRATIO.BAS` — Fibonacci with ratio to previous
- 3-column table; first ratio prints `N/A` to avoid divide-by-zero.

### `LEDDEMO.BAS` — Random LED patterns
- Random byte to LED port with small delay; `Ctrl-C` to stop.

---

## Folder Layout (suggested)

```
/mbasic     # MBASIC-80 sources (.BAS)
  LEDLAB10.BAS
  COLLINFO.BAS
  PRIMELED.BAS
  PRIMEFORE.BAS
  PRIMEGAP.BAS
  TOTIENT.BAS
  DIVCLASS.BAS
  DIVCLASS_SAVE.BAS
  STARFIELD.BAS
  FIBRATIO.BAS
  LEDDEMO.BAS
/forth      # CamelForth words/snippets (fast math + IO)
/docs       # Notes: port maps, cheatsheets, XMODEM usage, etc.
/tools      # Batch files or helper scripts (optional)
```

---

## Tips & Conventions

- **Drives:** `B:` is RAM (volatile), `C:` is SD (persistent). Do work on `B:`; copy to `C:` to keep:
  ```
  PIP C:=B:MYPROG.BAS
  ```
- **STAT:** Disk and file info:
  ```
  STAT
  STAT DSK:
  STAT B:*.*[FULL]
  ```
- **Delete:** `ERA FILENAME.EXT` (⚠ no recycle bin).  
- **FDISK80/CLRDIR/SYSCOPY/SYSGEN:** Use with care when prepping SD cards.  
- **Logging programs** write to the **current drive**—switch to `C:` before running if you want files on SD.

---

## Forth Corner (CamelForth)

The repo may include small CamelForth words for faster number crunching and simple I/O (e.g., a prime tester and a prime printer that exits on keypress).  
- Enter Forth: `FORTH` or from menu where available; exit with `BYE`.  
- **Why Forth?** It’s compact and fast on Z80, great for tight loops and direct port I/O.

---

## License (choose one)

> **SPDX:**  
> MIT → `MIT` · BSD 2-Clause → `BSD-2-Clause` · BSD 3-Clause → `BSD-3-Clause` · GPLv3 → `GPL-3.0-or-later`

### MIT License
Copyright (c) 2025

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the “Software”), to deal
in the Software without restriction, including without limitation the rights  
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell  
copies of the Software, and to permit persons to whom the Software is  
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in  
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR  
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,  
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER  
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,  
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN  
THE SOFTWARE.
