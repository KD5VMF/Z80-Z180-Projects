# SC7xx Retro Lab — Z80 / RomWBW (SC722 • SC131 • SC719 • SC794)  

- All Written byChat-GPT5 at the request of KD5VMF

A collection of small-but-fun programs and utilities for the SC7xx family running **RomWBW CP/M**:

- **MBASIC** math demos (primes, totient, Collatz “record hunter”), text effects, and LED drivers  
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

### `COLLINFO.BAS` — Collatz Record Hunter (LEDs + optional logging)
- **What it does:** Scans `1..N`. For each `n`, applies:
  - even → `n := n/2`
  - odd  → `n := 3*n + 1`
  Tracks **steps** to reach 1 and **peak** value along the chain.
- **Records printed:** `[NEW_MAX_STEPS]`, `[NEW_MAX_PEAK]` (or both).
- **Screen output (fixed-width):**  
  `n=… s=… p=… a=… avg=… [RECORD]`  
  where `a = peak/n` and `avg` is the running average of steps so far.
- **LEDs:** Shows **low 8 bits** of current chain value on `LEDPORT`, updated ~every 8 steps.
- **Prompts:**  
  - *Upper limit N (0 = very high)* → start with `20000`  
  - *Save results (Y/N)* → logs only new records to `COLLSTAT.TXT` if `Y`
- **Stop:** `Ctrl-C`.

### `PRIMELED.BAS` — Primes + LED mirror + stats file
- **What it does:** Scans up to `N`. For each prime prints prime number, **gap** from previous prime, and **count**.  
- **LEDs:** Mirrors low byte of the prime to `LEDPORT`.
- **File:** `PRIMESTA.TXT` (`prime,gap,count,maxgap`).
- **Stop:** `Ctrl-C`.

### `PRIMEFORE.BAS` — Primes forever (numbers only)
- **What it does:** Prints primes endlessly using sqrt trial division over odd candidates.  
- **Stop:** Press `Q` (uppercase or lowercase).

### `PRIMEGAP.BAS` — Prime & gap table to L
- **What it does:** Finds primes ≤ `L` and logs `prime, gap, running_max_gap`.  
- **Progress:** Prints every 500 primes.  
- **File:** `PRIMEGAP.TXT`.

### `TOTIENT.BAS` — Euler’s φ(n) table 1..N
- **What it does:** Efficiently computes φ(n) via the product formula (factor once per distinct prime factor).
- **Output:** `n,phi(n),phi(n)/n` in `TOTIENT.TXT`.  
- **Summary:** Prints running maximum φ(n) and final sum `Σ φ(n)`.

### `DIVCLASS.BAS` — Perfect / Abundant / Deficient
- **What it does:** For each `n` up to `N`, sums proper divisors and classifies:
  - **Perfect** if sum = n (e.g., 6, 28)
  - **Abundant** if sum > n
  - **Deficient** if sum < n
- **Screen:** row per `n`, periodic counts, final tallies and largest “excess” (`sum - n`).

### `DIVCLASS_SAVE.BAS` — Same, with logging
- **File:** `DIVCLASS.TXT` (`n,sum_proper_divisors,kind`) with periodic progress and same final summary.

### `STARFIELD.BAS` — ANSI/VT100 starfield
- **What it does:** Clears screen with ANSI, animates 50 stars, wraps edges.  
- **Terminal:** Needs VT100/ANSI escape support (most modern terminals do).  
- **Stop:** `Q`.

### `FIBRATIO.BAS` — Fibonacci with ratio to previous
- **What it does:** Prints `(term, fib, ratio)` where `ratio := F(n)/F(n-1)` tends to φ ≈ 1.618034.  
- **Edge case:** The first ratio prints `N/A` to avoid divide by zero.

### `LEDDEMO.BAS` — Random LED patterns
- **What it does:** Outputs random bytes to `LEDPORT` with a small delay so changes are visible.  
- **Tweak speed:** Adjust the inner delay loop.  
- **Stop:** `Ctrl-C`.

---

## Folder Layout (suggested)

```
/mbasic     # MBASIC-80 sources (.BAS)
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

The repo also includes small CamelForth words for faster number crunching and simple I/O (e.g., a prime tester and a prime printer that exits on keypress).  
- Enter Forth: `FORTH` or from menu where available; exit with `BYE`.  
- **Why Forth?** It’s compact and fast on Z80, great for tight loops and direct port I/O.

---

## License & Contributions

- Pick a license you’re comfortable with (MIT/BSD/GPL) and add `/LICENSE`.  
- PRs welcome: new MBASIC/Forth examples, port maps for different SC7xx builds, or docs improvements.
