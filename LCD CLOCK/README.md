# LCD CLOCK — SC126/RCBus + SC719 LCD1602 Clock (Z80/Z180, RomWBW)

A tiny, rock-solid LCD clock for **RomWBW CP/M** systems that have an **SC719 I/O + LCD1602** wired per the Small Computer Central example. https://smallcomputercentral.com/examples/example-alphanumeric-lcd/

It reads the real-time clock using the **RomWBW HBIOS** service (`RTCGETTIM`) and displays:

- **Centered time** on the top row: `HH:MM:SS` (with blinking `:`)
- **Centered date** on the second row: `20YY-MM-DD`

No terminal output, no BDOS printing, no monitor/ROM console calls — just clean LCD updates once per second.

---

## Features

- ✅ **Stable, clean LCD output** (no garbage / no random port blasting)
- ✅ Updates **only when the seconds value changes**
- ✅ **Blinking colons** for a classic clock look
- ✅ Safe CP/M behavior:
  - Uses a stack **inside the COM image**
  - No writes into BDOS/BIOS memory
- ✅ Tested workflow on **SC126** with **SC719** base port **00h**

---

## Hardware Requirements

- **CPU / Bus**: Z80/Z180
- **RomWBW** with CP/M and HBIOS enabled
- **RTC supported by RomWBW** (HBIOS `RTCGETTIM`)
- **SC719 I/O module** (or compatible) connected to an **LCD1602** (HD44780) @ 00H <-- This can be change in the ASM file.

### LCD Wiring (SC719 → LCD1602, 4-bit mode)

This program assumes the SCC example mapping:

| SC719 bit | Signal |
|----------:|--------|
| bit2      | RS     |
| bit3      | E      |
| bit4..7   | D4..D7 |
| R/W       | GND (tied LOW) |

> LCD must be in 4-bit mode, and R/W must be tied low.

### I/O Base Address

Default is:

- `PORT_LCD = 00H`

So set your SC719 base/jumper to **00h**.

If you use a different base, edit this line in the ASM:

```asm
PORT_LCD    EQU     00H
```

---

## Software Requirements

- **RomWBW CP/M** running on your system
- A way to upload a file to CP/M (serial, SD, etc.)
- A Z80 assembler on CP/M (commonly **ZASM**, **MAC**, or **ASM** depending on your build)
- https://www.asm80.com/  - Nice online Assembler

---

## Files

- `LCDCLK.ASM` — source code (8080 mnemonics, assembles fine on Z80 assemblers)

Output:
- `LCDCLK.COM` — CP/M executable

---

## Build (assemble to .COM)

### Option A: Assemble on CP/M (recommended)
Exact command depends on your assembler. Examples:

**If using `ZASM`:**
```text
A> ZASM LCDCLK.ASM LCDCLK.COM
```

**If using `ASM` / `MAC` style tools:**
```text
A> ASM LCDCLK
A> LOAD LCDCLK
```

If your assembler produces `.HEX` first, then use `LOAD` to convert it to `.COM` (see next section).

---

## Uploading with ED + HEX → COM workflow (the classic way)

This section is for the “pure CP/M” workflow where you **type/paste** the Intel HEX text into a file using **ED**, then convert it to a runnable `.COM`.

### 1) Create the HEX file using ED

Start ED and create a new file (example name: `LCDCLK.HEX`):

```text
A> ED LCDCLK.HEX
```

Inside ED:

1. Enter input mode:
   ```text
   i
   ```
2. Paste/type the Intel HEX records (the `:...` lines).
3. End input mode with:
   ```text
   ^Z
   ```
4. Write the file and exit:
   ```text
   e
   ```

You should now have:
```text
A> DIR LCDCLK.HEX
```

> Tip: If you’re pasting from a terminal program, enable “paste delay” if needed so CP/M doesn’t drop characters.

---

### 2) Convert HEX to COM using LOAD

CP/M’s `LOAD` converts Intel HEX into a `.COM` executable.

Run:

```text
A> LOAD LCDCLK
```

That reads `LCDCLK.HEX` and creates `LCDCLK.COM`.

Verify:
```text
A> DIR LCDCLK.COM
```

---

### 3) Run it

Just execute the program:

```text
A> LCDCLK
```

You should see the LCD update once per second:

- Top row: centered time `HH:MM:SS` with blinking colons  
- Bottom row: centered date `20YY-MM-DD`

To stop it, reset/break out (depends on your system — many RomWBW setups use `Ctrl+C` or a reset button).

---

## Troubleshooting

### LCD shows nothing
- Confirm SC719 base address is **00h**
- Confirm LCD wiring matches the bit mapping (RS=bit2, E=bit3, D4..D7=bits4..7)
- Ensure LCD **R/W is tied to GND**
- Verify LCD contrast pot is set correctly

### LCD shows garbage
- Usually wiring mismatch (RS/E swapped, D4..D7 miswired)
- Confirm you are using **4-bit mode wiring** and the pins are correct
- Confirm you did not modify the program to write random patterns to the port

### Program crashes or prints “BAD INT”
- That happens when the stack overlaps CP/M/BIOS memory.
- This program avoids that by placing the stack inside the COM image. If you modified stack settings, revert them.

---

## Notes / Design Details

- RTC is read using **RomWBW HBIOS** service `RTCGETTIM` via `RST 1`
- RTC returns six packed BCD bytes: `YY MM DD HH MM SS`
- The display updates only when the **seconds** byte changes, so it’s stable and efficient.

---

## License

Use it, modify it, share it. If you publish improvements, please consider opening a PR so everyone benefits.

---

## Credits

- Small Computer Central SC719 LCD example wiring (HD44780 4-bit interface)
- RomWBW / HBIOS for RTC access
