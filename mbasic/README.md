# SC7xx Retro Lab — Z80 / RomWBW (SC722 • SC131 • SC719 • SC794)

- All written by Chat-GPT5 at the request of **KD5VMF**

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

```
C:
MBASIC
LOAD "PROGRAM.BAS"
RUN
```

- Save edits: `SAVE "PROGRAM.BAS"`  
- Exit to CP/M: `SYSTEM`  
- List BASIC files: `DIR *.BAS`

**Serial transfer (XMODEM):**

- Receive PC → SC7xx:
  ```
  XM RK FILENAME.COM
  ```
  Then in your PC terminal, **Send via XMODEM-1K (CRC)**.

- Send SC7xx → PC:
  ```
  XM S FILENAME.COM
  ```

---

## LED Port Note (front-panel LEDs)

Several programs drive front-panel LEDs. The default is:

```basic
LEDPORT = &H00   ' SC719 typical demo port
```

If your board maps LEDs elsewhere, edit that constant in the source (e.g., `&H80`). The programs update LEDs slowly enough to see patterns.

---

## NEW: MAX7219 8×8 LED Matrix (MBASIC)

**File:** `MAX7219.BAS`  
**What it is:** A fast MAX7219 driver + art demo for one 8×8 LED matrix. Includes a **bouncing ball** animation, diagonal sweep, expanding box pulse, rain/twinkle, and wave patterns. Menu lets you **cycle all** or pick a single effect and set speed.

### Wiring (single module)

Use the **IN** header on the MAX7219 module (often labeled `VCC GND DIN CS CLK`). Do **not** wire to the OUT/DOUT side.

- **MAX7219 VCC** → **+5 V**
- **MAX7219 GND** → **GND** (must be common with SC7xx)
- **MAX7219 DIN** → SC7xx **data bit**
- **MAX7219 CS**  → SC7xx **chip-select bit**
- **MAX7219 CLK** → SC7xx **clock bit**

**SC719 (your wiring):**
- DIN on **IO pin 0** (bit0)  
- CS  on **IO pin 1** (bit1)  
- CLK on **IO pin 2** (bit2)  
- Port assumed **&H00**

In `MAX7219.BAS`, these are the masks at the top:

```basic
30 P = &H00      ' I/O port (change if your IO header is a different port)
40 BDIN = 1      ' IO pin 0  -> mask 1
50 BCS  = 2      ' IO pin 1  -> mask 2
60 BCLK = 4      ' IO pin 2  -> mask 4
```

**Alternative example (older mapping you tried):**
- DIN on pin 4 → mask **16**
- CS  on pin 6 → mask **64**
- CLK on pin 8 → mask **128**

Then set:
```basic
40 BDIN = 16
50 BCS  = 64
60 BCLK = 128
```

### Run it

```
C:
MBASIC
LOAD "MAX7219.BAS"
RUN
```

- You’ll see a menu:  
  `Modes: 0=Cycle  1=Ball  2=Diag  3=Box  4=Rain  5=Wave`  
  Then speed prompt: `SPD (0=fast, 1..9 slower)`
- Try **Mode=1** (Ball) and **SPD=0** for fastest.

### Tuning & Notes

- **Brightness:** edit the **INTENSITY** register in the init code (0..15). The program sets it to **8** by default.  
- **MBASIC 5.21 quirks already handled:**  
  - No underscores in variable names  
  - No `:` (multi-statement lines)  
  - No inline `'` comments (uses `REM`)  
  - Avoid reserved words (e.g., we use `DB` instead of `DATA`, `V` instead of `VAL`)
- **Electrical:** MAX7219 modules want a solid **5 V**. Many 8×8 boards pull ~100–300 mA depending on intensity/content. Keep **GND common** with the SC7xx.  
- **Speed tips:** Use `SPD=0`. The driver uses a precomputed bit mask table and minimal delay loops; for even more speed, a tiny Z80 routine to clock DIN/CLK/CS will beat MBASIC.  
- **Mirrored image?** If the matrix appears flipped left/right, swap bit order in the pixel routine, or rotate the module.

### Troubleshooting

- **Blank matrix:**  
  - Confirm you used the **IN** header (`DIN CS CLK`), not the OUT/DOUT header.  
  - Check **5 V** and **GND** continuity to the module; GND must be common with the SC7xx.  
  - Verify masks match your actual IO bits; try toggling each bit manually from MBASIC (`OUT &H00,1`, `OUT &H00,2`, `OUT &H00,4`) and meter the lines.  
- **Only some rows/columns light:** poor solder on the 8×8, or scan-limit not set; the program sets **SCAN_LIMIT = 7** (all 8 rows).  
- **Too dim/bright:** change the **INTENSITY** register (0..15).  
- **Chain won’t work:** this program addresses **one** device. For daisy-chains, send **N 16-bit words** per write, last device first, and use **NO-OP (0x00)** for words targeting earlier devices.

---

## Program Index (MBASIC)

| Program           | Category     | What it does                                                                 | Input/Prompt                       | Screen Output                            | File Output           | LEDs / Matrix |
|-------------------|--------------|------------------------------------------------------------------------------|------------------------------------|-------------------------------------------|-----------------------|---------------|
| `MAX7219.BAS`     | Visual/I-O   | **MAX7219 8×8 Matrix** demo: Ball, Diag, Box, Rain, Wave; **0=cycle all**   | Mode (0–5), SPD (0–9)              | Menu + effect banners                     | —                     | Matrix ✔      |
| `BYTEGLOW.BAS`    | I/O/Visual   | **ByteGlow**: 9 LED patterns; `0=cycle`, `+/-` speed, `I` invert, `Q` quit  | —                                  | Pattern label + hints                     | —                     | Front LEDs ✔  |
| `LEDLAB10.BAS`    | I/O/Visual   | **LED Math Lab**: 10 patterns; **mode 0 = cycle all**                        | Delay; Mode (0–10)                 | Mode banner; `Q` back to menu             | —                     | Front LEDs ✔  |
| `COLLINFO.BAS`    | Math/Heavy   | **Collatz Record Hunter** (records on steps/peak, optional log)              | N (0 = huge), save Y/N             | Compact progress + record lines           | `COLLSTAT.TXT` (opt.) | ✔             |
| `PRIMELED.BAS`    | Math         | Prime scanner + **gap** + **count**; LEDs mirror low byte                    | N (upper limit)                    | Prime lines + periodic summary            | `PRIMESTA.TXT`        | ✔             |
| `PRIMEFORE.BAS`   | Math         | Primes forever (numbers only); `Q` quits                                     | —                                  | Numbers scrolling                         | —                     | —             |
| `PRIMEGAP.BAS`    | Math/Table   | Primes ≤ N with **gap** and running **max gap**                              | L (limit)                          | Periodic progress every 500 primes        | `PRIMEGAP.TXT`        | —             |
| `TOTIENT.BAS`     | Math/Table   | Euler’s **φ(n)** for 1..N (distinct-prime factorization)                     | N (limit)                          | Periodic progress                         | `TOTIENT.TXT`         | —             |
| `DIVCLASS*.BAS`   | Math/Table   | Proper-divisor sum → **Perfect/Abundant/Deficient**                          | N (limit)                          | Tallies + summary                         | `DIVCLASS.TXT` (save) | —             |
| `STARFIELD.BAS`   | Visual       | ANSI/VT100 starfield animation; `Q` quits                                    | —                                  | Animated starfield                        | —                     | —             |
| `FIBRATIO.BAS`    | Math/Demo    | Fibonacci with running ratio → golden ratio                                  | N (terms)                          | Neat 3-column table                       | —                     | —             |
| `LEDDEMO.BAS`     | I/O/Visual   | Random LED patterns at LED port with gentle delay                            | —                                  | “Press Ctrl-C to stop…”                   | —                     | ✔             |

CSV files are simple and easy to import into a spreadsheet.

---

## Folder Layout (suggested)

```
/mbasic     # MBASIC-80 sources (.BAS)
  MAX7219.BAS
  BYTEGLOW.BAS
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
- **FDISK80 / CLRDIR / SYSCOPY / SYSGEN:** Use with care when prepping SD cards.  
- **Logging programs** write to the **current drive**—switch to `C:` first if you want files on SD.

---

## MBASIC-80 Rev 5.21 “Gotchas” (we already accounted for these)

- Variable names are letters/digits only (no `_`).  
- No `:` multi-statement lines.  
- No inline `'` comments; use `REM`.  
- Some names are reserved (e.g., `DATA`, `VAL`).  
- `IF ... THEN` can assign or `GOTO`; longer logic should be spread across lines.  
- To seed `RND`, assign the call: `RN = RND(-1)`.

---

## License

**SPDX-License-Identifier: MIT**

```
MIT License

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
```
