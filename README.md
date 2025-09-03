# Z80/Z180 Projects — SC7xx (CP/M & RomWBW)
# (e.g., SC722, SC719, SC131, SC126, SC794)

A curated collection of **Z80/Z180** programs, demos, and utilities targeting the **Small Computer Central SC7xx** ecosystem (e.g., SC722, SC719, SC131, SC126, SC794) running **RomWBW CP/M 2.2** and compatibles.

> This repository grows over time. Each subfolder includes its own README with build/run notes and any board-specific jumpers or port mappings.

---

## Goals

- **On‑target CP/M builds** using `ASM.COM` (8080 syntax) + `LOAD.COM`, and **MBASIC**.
- **Clean, minimal examples** that are easy to copy, modify, and learn from.
- **SC7xx-friendly I/O** conventions (e.g., LED latch at `port 00h` by default).
- Optional **cross‑assembly** from a modern PC, then transfer via serial/XMODEM or CF.

---

## Repository Layout (intended)

```
/
├─ Setup Stuff/      # One-time setup, transfer scripts, terminal configs, tips
├─ CPm Stuff/        # CP/M utilities, COM builders, disk/CF helpers, DDT/inspect
├─ mbasic/           # MBASIC programs (math demos, LED effects, experiments)
├─ asm/              # 8080/Z80 assembly sources (programs & libraries)
├─ docs/             # Pin maps, I/O port notes, board jumpers, references
└─ tools/            # Cross-assemblers, host-side helpers (optional)
```
> Each folder should carry a short **README.md** describing content, build steps, and expected output.

---

## Quick Start (On‑Target CP/M 2.2)

### Assemble 8080‑syntax sources (for `ASM.COM` + `LOAD.COM`)
```text
A>ED PROGRAM.ASM
*I
; paste source (8080 mnemonics for ASM.COM)
^Z
*E

A>ASM PROGRAM
A>LOAD PROGRAM
A>PROGRAM
```

### Run MBASIC programs
```text
A>MBASIC PROGRAM.BAS
```

### Inspect / verify
```text
A>DDTZ PROGRAM.COM
U 0100   ; unassemble from COM base
```
or dump bytes:
```text
A>DUMP PROGRAM.COM
```

---

## Cross‑Assembly (Optional)

- Use **sjasmplus** or **z80asm** on a modern machine for Z80 mnemonics.
- Keep **8080** (for CP/M `ASM.COM`) and **Z80** sources in separate folders.
- Ensure COM targets start at **`ORG 100h`** (or link accordingly).
- Transfer binaries to SC7xx via **XMODEM**, **Kermit**, or by writing a CF card.

---

## I/O Conventions

- **LED latch**: examples default to **`port 00h`** (change `LED_PORT EQU 0` as needed).
- **Console**: portable BDOS calls; non‑blocking reads typically use **BDOS 6** with `E=0FFh`.
- **Clock/RTC, CF/IDE, UART**: document any board‑specific jumpers in each program’s README.

---

## Code Style

- Header block at top of each source with: CPU, syntax (8080 or Z80), toolchain, ports, build steps.
- Prefer small, self‑contained modules and visible `ORG 100h` for COMs.
- Use `EQU` for constants/ports; document timing loops and CPU clock assumptions.
- Keep examples runnable “as‑is” on a stock RomWBW CP/M system.

---

## Roadmap Ideas

- LED suite (counters, patterns, binary clock, visualizers)  
- Console tools (hexdump, peek/poke, RAM/ROM dumpers)  
- Math demos (primes, Collatz, integer benchmarks)  
- Storage helpers (INITDIR/FDISK walkthroughs, disk tools)  
- Diagnostics (UART loopback, port scanners, timing tests)  
- Peripheral experiments (RTC readouts, SPI/I2C bit‑bang demos)

---

## Contributing

1. Create or choose the appropriate folder (e.g., `asm/led/fastled/`).  
2. Add:
   - `PROGRAM.ASM` **or** `PROGRAM.BAS`
   - `README.md` with build/run steps and expected output
   - Optional: `PROGRAM.COM` and a short log/screenshot
3. Test on at least one SC7xx board (note jumpers/ports if relevant).
4. Commit with a concise message (what it does + how to run).

---

## License

Recommended: **MIT** for top‑level. If a sub‑project needs something different, note it in that folder’s README.

---

**Have fun!** Small, clear examples are the best building blocks. Commit early, document briefly, and keep iterating.


Maybe a Easter Egg... on boot press e and see a Mandelbrot!

Boot [H=Help]: e

Loading ...Generating a Mandelbrot set...

Small Computer SC700 [SCZ180_sc700_std] Boot Loader
