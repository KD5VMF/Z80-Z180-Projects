# Small Computer Central — SC700 Series Field Manual (Unofficial Companion)
**Revision:** 2025-08-29  
**Prepared for:** SC700/RCBus builders and tinkerers  
**Scope:** Consolidates module overviews, jumper maps, I/O address conventions, and quick programming notes for the SC700 (80‑pin RCBus) ecosystem. This is an unofficial companion compiled from public docs by Small Computer Central (SCC) plus practical notes for CP/M/RomWBW users.

> **Disclaimer**: This guide paraphrases vendor documentation and community notes. When in doubt, prefer the specific module’s official “User Guide” and schematic on the SCC site.

---

## Table of Contents
1. [RCBus Overview](#rcbus-overview)
2. [I/O Address Conventions](#io-address-conventions)
3. [Module Catalog (SC700 Series)](#module-catalog-sc700-series)
   - SC705 Serial ACIA (68B50)
   - SC716 Z80 SIO/2 serial (dual)
   - SC725 SIO/2 + CTC
   - SC717 Z80 PIO
   - SC718 Z80 CTC
   - SC719 Digital I/O (8 in / 8 out)
   - SC727 RTC (DS1302)
   - SC715 CompactFlash
   - (Pointers to SC707/714/721 memory, SC701/702/709/710 backplanes, SC720/722 motherboards)
4. [Jumper & Header Quick Reference](#jumper--header-quick-reference)
5. [Programming Notes & Examples](#programming-notes--examples)
   - Port I/O (8080/Z80)
   - SIO/2 register map & baud basics
   - CTC basics & the “magic numbers”
   - PIO port/control usage
   - RTC via RomWBW HBIOS (RST 1)
   - Digital I/O examples (SC719)
6. [RomWBW Integration Cheats](#romwbw-integration-cheats)
   - Serial port speed (MODE)
   - File transfer (XM/XMODEM)
7. [Appendix A: Typical Addresses Cheat‑Sheet](#appendix-a-typical-addresses-cheat-sheet)
8. [Appendix B: Connector Pinouts (selected)](#appendix-b-connector-pinouts-selected)
9. [Appendix C: Troubleshooting](#appendix-c-troubleshooting)
10. [Links to Official Docs](#links-to-official-docs)

---

## RCBus Overview
RCBus is an extended, RC2014‑compatible bus with 80‑pin, 60‑pin (enhanced), and 40‑pin variants. It adds support for features like Z80 interrupt daisy‑chain (IEI/IEO), CLK2, extra serial pins (TX2/RX2), and broader CPU families. See the official RCBus v1.0 spec for signal definitions and mechanical notes.

**Key ideas**
- **Tight address decoding** on SCC modules; most can be relocated with jumpers (JP1).
- **Backplane differences:** Not all 40‑/60‑pin backplanes carry CLK2 or the daisy‑chain; some features require wires/jumpers or an 80‑pin RCBus backplane.
- **Clocking**: Many serial setups assume 7.3728 MHz clocks for “round” baud rates.

---

## I/O Address Conventions
SCC publishes a de‑facto map of common assignments (not a universal standard). Highlights that matter most in mixed systems:

- **0x00–0x03**: Digital I/O (SC719 and relatives).  
- **0x0C**: RTC DS1302 and/or I²C master (shared on some builds).  
- **0x10–0x17**: CompactFlash (SC715/SC729/SC720).  
- **0x68–0x6B**: Z80 PIO #1 (SC717).  
- **0x80–0x83**: Z80 SIO/2 #1 (SC716, SC725, SC720).  
- **0x88–0x8B**: Z80 CTC #1 (SC718, SC725).

> **Tip:** Default/“typical” addresses are provided below per module. Always check JP1 on the module and your firmware expectations to avoid clashes.

---

## Module Catalog (SC700 Series)

### SC705 — Serial ACIA (68B50)
**What it is:** Single async serial port using 68B50 ACIA. Fixed‑clock design commonly used at **115200 8N1**.  
**Typical base address:** `0x80` (occupies two ports, base and base+1).  
**Why pick it:** Simple, predictable, minimal setup for CP/M/SCM; fits 40/60/80‑pin systems (with feature limits on smaller backplanes).  
**Jumpers (high level):**  
- JP1: I/O base select (binary).  
- JP2: Option to power serial port from board.  
- JP3: Interrupt to INT/INT1/INT2.  
- JP4: Clock source (on‑board crystal vs bus CLK).  
- JP5/JP6: E and R/W signal source (Z80 vs 68xx style).

**Register usage:** ACIA has a **data** port and a **status/control** port. Most SCC firmware expects the default 115200; custom baud needs matching clocks or SCM writes.

---

### SC716 — Z80 SIO/2 (Dual Serial)
**What it is:** Zilog SIO/2 with independent clocking (on‑board oscillator or bus CLK2).  
**Typical base address:** `0x80` or `0x84` (4 ports total).  
**Register map (relative to base):**
- `+0` Port A **control**  
- `+1` Port A **data**  
- `+2` Port B **control**  
- `+3` Port B **data`

**Jumper flavor:** JP1 selects I/O base; JP2/JP3 choose clock source per port; JP4–JP7 tie RX/TX/RTS/CTS to bus pins; JP8/JP9 IEI/IEO (daisy chain); JP10/JP11 optional 5V out to ports.

**Notes:** With 7.3728 MHz and SIO divide‑by‑64 you get **115200**. Using CLK2 or CTC allows software‑selectable baud.

---

### SC725 — SIO/2 + CTC (Dual Serial + 4 Timers)
**What it is:** Combines Z80 SIO/2 and Z80 CTC. Two serial ports **and** four timer/counter channels.  
**Typical addresses:**  
- SIO/2 at `0x80–0x83`  
- CTC at `0x88–0x8B`

**“Magic numbers” for baud** (CTC input 7.3728 MHz):  
- SIO divide **16** → TC values: 1→230400, 2→115200, 4→57600, 6→38400, 12→19200, 16→14400, 24→9600, 48→4800, 96→2400, 192→1200  
- SIO divide **64** → TC values: 1→57600, 2→28800, 3→19200, 4→14400, 6→9600, 12→4800, 24→2400, 48→1200, 96→600, 192→300

**Why pick it:** One card yields flexible baud generation and a periodic interrupt source. Great for RomWBW/SCM builds needing both serial and timers.

---

### SC717 — Z80 PIO (16 GPIO + Handshakes)
**What it is:** Z80 PIO for **16 GP I/O** plus handshakes.  
**Typical base address:** `0x68` (4 ports: A‑data, B‑data, A‑ctrl, B‑ctrl).  
**Use cases:** Parallel peripherals, keypad, simple buses, handshaked transfers.  
**Interrupts:** Supports Z80 mode‑2 daisy chain via IEI/IEO or backplane jumpers.

---

### SC718 — Z80 CTC (4‑channel Counter/Timer)
**What it is:** General‑purpose timers, counters, clock generators, and mode‑2 interrupt generator.  
**Typical base address:** `0x88` (channels at base..base+3).  
**Inputs:** Per‑channel select: CLK, CLK2, onboard oscillator, or INT1/INT2.  
**Outputs:** Can drive CLK2 or chain CH2→CH3 for a 16‑bit timer.

---

### SC719 — Digital I/O (8 In / 8 Out with LEDs)
**What it is:** Simple, tight‑decode digital port for **8 inputs** and **8 outputs**, each with an LED. Single I/O port address.  
**Typical base address:** `0x00` (all JP1 shunts **not** fitted).  
**Programming:** `IN port` reads inputs; `OUT port` writes outputs; LED logic is transparent.

---

### SC727 — RTC (DS1302 + Spare I/O)
**What it is:** DS1302 real‑time clock with battery plus **2 inputs** and **4 outputs** exposed on a header.  
**Typical base address:** `0x0C` (Z180 builds) **or** `0xC0` (Z80 builds).  
**Port bit roles (at base address):**  
- **Read**: bit4=input4, bit5=input5; (other bits may read undefined or RTC data depending on firmware)  
- **Write**: bit0..3 are user outputs; **bit4** drives **RTC chip enable (active‑low)**; **bit5** drives **RTC write enable (active‑low)**; **bit6** RTC serial clock; **bit7** RTC serial data.  
**Firmware:** RomWBW adds an HBIOS call to get/set time (no need to bit‑bang).

---

### SC715 — CompactFlash
**What it is:** CF interface compatible with CP/M and RomWBW storage stacks.  
**Typical addresses:** `0x10–0x17` (CF registers).  
**Notes:** CP/M 2.2 usually sees up to **128 MB** of a card; RomWBW supports larger (often up to ~2 GB). Prefer older/slower CF for signal integrity.

---

### Other SC700 references
- **SC707 / SC714 / SC721** — memory modules for RomWBW/SCM banks.  
- **SC701/702/709/710** — 80‑pin backplanes.  
- **SC720** — Z80 motherboard running RomWBW CP/M; **SC722** — Z180 CPU module.

> For parts lists, PCBs, and schematics, see each module’s “User Guide” and downloads from SCC.

---

## Jumper & Header Quick Reference

> **Always check the silkscreen and the module’s User Guide**; the notes below are shorthand.

- **SC705 (ACIA)**: JP1 address; JP2 5V to port; JP3 interrupt line (INT/INT1/INT2); JP4 clock source; JP5/JP6 select E and R/W sources; JP7/JP8 bus RX/TX/CTS/RTS mapping.  
- **SC716 (SIO/2)**: JP1 base; JP2/JP3 clock source per port; JP4–JP7 connect TX/RX/RTS/CTS to TX/TX2/RX/RX2; JP8/JP9 IEI/IEO; JP10/JP11 5V to ports.  
- **SC725 (SIO/2+CTC)**: JP4 input clock to CTC; JP5/JP6 choose baud clock source to SIO A/B (CLK2 vs CTC vs “C”); JP1–3 power/IEI/IEO.  
- **SC717 (PIO)**: JP1 base; JP2/JP3 IEI/IEO chain.  
- **SC718 (CTC)**: JP1 base; JP2–JP5 channel input sources; JP6 route outputs to CLK2; JP7–JP10 INT/IEI/IEO options.  
- **SC719 (Digital I/O)**: JP1 base (no shunts → 0x00).  
- **SC727 (RTC)**: JP1 base; P2 header exposes user I/O and power.

---

## Programming Notes & Examples

### Port I/O (8080/Z80 mnemonics)
```asm
; OUT a byte (A) to I/O port N
MVI  A,0FFH
OUT  00H         ; turn on all SC719 outputs

; Read inputs from I/O port N
IN   00H
MOV  B,A         ; B has input bits
```

### SIO/2 (SC716/SC725) quick map
- base+0: control A  | base+1: data A  
- base+2: control B  | base+3: data B

**Baud basics:** With 7.3728 MHz → 115200 when SIO divider = 64. For programmable baud, feed the SIO from CTC (SC725) and load the CTC time constant per the tables below.

### CTC (SC718/SC725) “magic” time constants (input 7.3728 MHz)
- **SIO divide 16** → TC: 1=230400, 2=115200, 4=57600, 6=38400, 12=19200, 16=14400, 24=9600, 48=4800, 96=2400, 192=1200  
- **SIO divide 64** → TC: 1=57600, 2=28800, 3=19200, 4=14400, 6=9600, 12=4800, 24=2400, 48=1200, 96=600, 192=300

**Example (SC725):** set port B to 9600 with SIO÷16  
```
OUT 089H,055H    ; CTC CH1: no int, counter mode, rising edge, TC follows
OUT 089H,24      ; TC=24 → 9600 with SIO ÷16
```

### PIO (SC717) notes
- base+0: Port A data, base+2: Port A control  
- base+1: Port B data, base+3: Port B control  
Program control regs to set input/output modes, handshakes, and interrupts.

### RTC (SC727) via **RomWBW HBIOS**
- HBIOS function `RTCGETTIM`: **B=20h**, **HL** → 6‑byte buffer (YY,MM,DD,HH,MM,SS in **BCD**), **RST 1** entry.  
- Then convert BCD → ASCII for display.  
- Without RomWBW you would bit‑bang DS1302 on SC727’s port (bit4 CE low, bit5 WE low, bit6 SCLK, bit7 DATA). Prefer HBIOS where available.

### Digital I/O (SC719) examples
```asm
; Blink pattern on outputs @ 0x00
PAT:  DB 055H,0AAH,0FFH,000H
      LXI H,PAT
BLK:  MOV A,M
      OUT 00H
      INX H
      CPI 000H     ; stop at trailing 00 if you want
      JMP BLK
```

---

## RomWBW Integration Cheats

### Set console serial speed
```
A> MODE             ; show current
A> MODE COM0: 9600  ; set COM0 to 9600,N,8,1 (RomWBW syntax)
```

### Upload/download files with XMODEM
- On PC terminal: choose **XMODEM** (checksum) and send file.  
- On CP/M: `XM R FILENAME.COM` (receive) or `XM S FILENAME.COM` (send).  
- Ensure host and target baud match (use `MODE` first).

---

## Appendix A: Typical Addresses Cheat‑Sheet
- **SC719** Digital I/O → `0x00` (single port).  
- **SC727** RTC DS1302 → `0x0C` (Z180 builds) or `0xC0` (Z80 builds).  
- **SC715** CompactFlash → `0x10–0x17`.  
- **SC717** Z80 PIO → `0x68–0x6B`.  
- **SC716/SC725** SIO/2 #1 → `0x80–0x83`.  
- **SC718/SC725** CTC #1 → `0x88–0x8B`.

> Relocate with JP1 as needed to avoid conflicts; see each board’s silkscreen/user guide.

---

## Appendix B: Connector Pinouts (selected)

### SC725 Serial Port Headers (P1/S1 & P2/S2)
1: GND, 2: RTS, 3: +5V (optional), 4: RXD, 5: TXD, 6: CTS

### SC725 Interrupt Daisy Chain (JP3)
1: IEI, 2: IEO

### SC727 P2 (Spare I/O)
- Pins: 1=+5V, 2=Out0, 3=Out1, 4=GND, 5=Out2, 6=Out3, 7=+5V, 8=In4, 9=In5, 10=GND

---

## Appendix C: Troubleshooting

- **LEDs not responding (SC719)**: Confirm JP1 selects intended base; verify you’re writing the same port you’re reading; check active‑high LEDs; ensure backplane carries A0–A7 and IORQ/WR lines.  
- **RTC shows nonsense**: If using RomWBW, set time once with the built‑in tool (or your own program); confirm JP1 address matches HBIOS expectations (`0x0C` Z180 or `0xC0` Z80). Replace CR2032 if drift/clear on power‑off.  
- **Serial at wrong speed**: Check SIO/CTC jumper relationships (SC725 JP4/5/6); verify your clock source (CLK vs CLK2 vs onboard).  
- **CTC timer “does nothing”**: Load control then time constant; ensure channel input source jumper is set; if driving SIO, confirm SIO divider matches your “magic number” table.

---

## Links to Official Docs
- Small Computer Central, SC700 Series hub  
- Individual module “User Guide” pages (SC705, SC716, SC725, SC717, SC718, SC719, SC727, SC715)  
- RCBus I/O Address map  
- RCBus Specification v1.0 (PDF)

*End of document*
