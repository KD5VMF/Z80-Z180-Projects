# CP/M — Build & Run Guide (SC7xx / RomWBW)

This folder collects **CP/M 2.2** programs and notes for the **Small Computer Central SC7xx** family (SC719/SC722/SC131/SC794, etc.) running **RomWBW**.  
It teaches **how to make `.COM` programs** the classic way using `ED.COM`, `ASM.COM`, and `LOAD.COM`, with a complete worked example: **LEDCOUNT**.

> If you’re new to CP/M, read this once, then copy the pattern for future programs in this folder.

---

## Prerequisites

- A working **CP/M 2.2** prompt (RomWBW or compatible)
- `ED.COM` (editor), `ASM.COM` (assembler, 8080 syntax), `LOAD.COM` (linker)
- Optional: `DDTZ.COM` (Z80 unassembler), `DUMP.COM` (hex dump), `PIP.COM`
- A serial terminal (e.g., **Tera Term**) with **paste delay ~15 ms/line** to avoid overruns when pasting source code

> ⚠️ `ASM.COM` uses **8080 mnemonics**. If you want Z80 mnemonics, use a cross‑assembler on your PC and transfer the binary instead.

---

## The CP/M `.COM` Program Pattern

Every simple CP/M program that runs as a `.COM` should:
- Assemble for **8080 syntax** (for `ASM.COM`)  
- Start at **`ORG 100H`** (COM programs load at 0100h)  
- End with **`END START`** (or your entry label)  
- Use BDOS calls via `CALL 5` if you need console I/O

Minimal template:
```asm
; PROGRAM.ASM — CP/M 2.2 (8080 syntax for ASM.COM)
BDOS       EQU 5
        ORG 100H

START:  ; your code here
        RET             ; return to CP/M

        END START
```

Build/run:
```text
A>ASM PROGRAM
A>LOAD PROGRAM
A>PROGRAM
```

---

## Worked Example: LEDCOUNT (00→FF on LED port)

The **LEDCOUNT** example shows how to paste a full source file, assemble it into a `.COM`, and run it.

### 1) Create the source with ED
```text
A>ED LEDCOUNT.ASM
*I
; paste the full LEDCOUNT source here (see LEDCOUNT Build.txt in this folder)
^Z
*E
```

> Tip (Tera Term): `Setup → Serial port... → Transmit delay → Line: 15 msec`

### 2) Assemble & link
```text
A>ASM LEDCOUNT
A>LOAD LEDCOUNT
```

If assembly succeeded, you’ll have **LEDCOUNT.COM**.

### 3) Run
```text
A>LEDCOUNT
```
- The program outputs a **00..FF** count to the LED port (default **port 00h**).  
- **Q** or **q** exits (LEDs are cleared on exit).  
- Edit `LED_PORT EQU 0` if your hardware uses a different latch port.  
- Adjust speed in the delay loop (`MVI B,xx`).

**Full source** is included in `LEDCOUNT Build.txt` in this folder. Copy/paste it into `ED` exactly as shown there.

---

## Teaching Corner: Why This Works

- **`.COM` format**: CP/M loads the file at **0100h** and jumps to **0100h**. That’s why we use `ORG 100H` and place our entry label there.  
- **Editor → Assembler → Linker**: `ED` saves plain text, `ASM` turns it into a `.HEX`, and `LOAD` converts that to a `.COM`.  
- **BDOS calls**: `CALL 5` (at address 0005h) invokes CP/M’s BDOS services. For **non‑blocking key checks**, LEDCOUNT uses **BDOS function 6** with `E=0FFh` (returns 0 if no key).  
- **I/O ports**: `OUT 00H` writes to port 0. Many SC7xx examples map LED latches at port 00h; change `LED_PORT EQU 0` if yours differs.

---

## Verifying & Troubleshooting

- **Unassemble to confirm ports**:
  ```text
  A>DDTZ LEDCOUNT.COM
  U 0100
  ```
  You should see `OUT 00` if `LED_PORT EQU 0`.

- **Hex check**:
  ```text
  A>DUMP LEDCOUNT.COM
  ```
  Look for bytes **D3 00** (`OUT 00h`).

- **Paste overruns**: If `ASM` shows weird errors after a long paste, increase terminal **line delay** (e.g., 15–20 ms/line).

- **Active‑low LEDs**: If your LEDs are wired active‑low, the pattern will look inverted. You can `CMA` (complement A) before `OUT` to invert.

- **Block on input**: If a program “stalls,” ensure it uses **non‑blocking** BDOS calls (LEDCOUNT already does).

---

## Adding Your Own Programs

1. Create a new subfolder for each program (e.g., `LEDCOUNT/`, `HEXDUMP/`).  
2. Include:
   - `PROGRAM.ASM` (8080 syntax for `ASM.COM`)  
   - `README.md` with a short description, build/run steps, and expected output  
   - Optional: the built `PROGRAM.COM` and a small screenshot/log
3. Keep **ports and constants** at the top with `EQU` so others can adapt easily.
4. Note any **board jumpers** or wiring specific to SC7xx variants.

---

## Quick Reference (Cheat Sheet)

```text
Create:   ED PROG.ASM   → *I → paste → ^Z → *E
Assemble: ASM PROG
Link:     LOAD PROG
Run:      PROG

Verify:   DDTZ PROG.COM → U 0100
Dump:     DUMP PROG.COM
```

---

### See also
- `LEDCOUNT Build.txt` — full, paste‑ready source and step‑by‑step build for LEDCOUNT.
- More examples will appear in this folder over time. Keep each program’s README close to its source.
