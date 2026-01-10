#!/usr/bin/env python3
"""ihex_to_com.py - Convert Intel HEX to CP/M .COM (flat binary).

Usage:
  python3 ihex_to_com.py input.hex output.com

Notes:
  - Output starts at the LOWEST address found in the HEX file.
  - Any gaps are filled with 0x00.
  - If your program is ORG 0100h (typical .COM), you should jump/run at 0100h.
"""
import sys

def parse_ihex(lines):
    mem = {}
    base = 0
    lo = None
    hi = 0
    for line in lines:
        line = line.strip()
        if not line or not line.startswith(":"):
            continue
        bc = int(line[1:3], 16)
        addr = int(line[3:7], 16)
        rt = int(line[7:9], 16)
        data = bytes.fromhex(line[9:9 + bc*2])
        if rt == 0x00:
            abs_addr = base + addr
            lo = abs_addr if lo is None else min(lo, abs_addr)
            for i, b in enumerate(data):
                mem[abs_addr + i] = b
            hi = max(hi, abs_addr + bc - 1)
        elif rt == 0x01:
            break
        elif rt == 0x04:
            base = int.from_bytes(data, "big") << 16
        elif rt == 0x02:
            base = int.from_bytes(data, "big") << 4
    return mem, lo, hi

def main():
    if len(sys.argv) != 3:
        print("Usage: python3 ihex_to_com.py input.hex output.com")
        return 2
    inp, outp = sys.argv[1], sys.argv[2]
    with open(inp, "r", encoding="utf-8", errors="ignore") as f:
        mem, lo, hi = parse_ihex(f.readlines())
    if lo is None:
        print("No data records found in HEX file.")
        return 1
    data = bytes(mem.get(a, 0) for a in range(lo, hi + 1))
    with open(outp, "wb") as f:
        f.write(data)
    print(f"Wrote {len(data)} bytes from {hex(lo)}..{hex(hi)} -> {outp}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
