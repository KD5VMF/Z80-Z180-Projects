# Build (OshonSoft) and Load (SC720)

This repo was built around:

- **OshonSoft Z80 Simulator IDE v14.91**
- Author: **Vladimir Soso**
- Official site (for reference):
```text
https://www.oshonsoft.com/
```

## Build in OshonSoft

1. Open `src/Z80-LCD-Primes.asm`
2. Assemble it (Build / Assemble).
3. OshonSoft will generate:
   - `Z80-LCD-Primes.hex` (Intel HEX)
   - `Z80-LCD-Primes.lst` (listing)

Those prebuilt outputs are already included in `build/`.

## Run on the SC720 board

### Option A: Use your monitor/ROM loader “LOAD” (Intel HEX)

Most SC720 setups have a command like `LOAD` that receives Intel HEX over the serial port.

Typical flow:

1. Connect with your terminal program (same settings you use normally for the SC720).
2. At the SC720 prompt, start the loader (example):
   - `LOAD`   (or whatever your monitor calls it)
3. Send `build/Z80-LCD-Primes.hex` as plain text (ASCII) to the serial port.
4. When the loader finishes, jump to the program start:
   - The program is assembled at **ORG 0100h**
   - Use your monitor jump/go command (example):
     - `G 0100`   (or `GO 0100`)

### Option B: If you are under CP/M

Some CP/M systems include the utility `LOAD` (or similar) that converts Intel HEX into a `.COM`.
If so, you can:
1. Transfer `Z80-LCD-Primes.hex` onto your CP/M disk.
2. Run the converter tool.
3. Execute the `.COM`.

(Exact commands vary by monitor/CP/M build — Option A is the most universal for “raw” board loading.)
