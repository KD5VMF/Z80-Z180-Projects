# SC126 — Z180 Motherboard (RCBus/RC2014-Compatible)
**Unofficial Companion Manual** · Revision 2025-08-29  
Author: ChatGPT (compiled from Small Computer Central docs and community notes)

> This manual consolidates the information scattered across SC126 pages (overview, circuit explained, assembly guide, and software quick-start) into one practical reference for builders and programmers. Always prefer the official pages for definitive details and updates.

---

## 1) What is SC126? (Quick Overview)
**SC126** is a Z180-based single-board computer and motherboard that exposes **three 80‑pin RCBus sockets** so you can add RC2014/RCBus modules. Typical kit includes:
- **Z8S180** CPU @ **18.432 MHz** (optionally software-multiplied to ~**36.864 MHz** with fast parts)
- **512 KB RAM**, **2× 512 KB Flash ROM** (selectable)  
- **Two 5 V FTDI-style async serial ports** (Port A with RTS/CTS; Port B without CTS)  
- **Two 5 V SPI ports** (commonly used with an SD adapter)  
- **Bit-banged 5 V I²C master port**  
- **DS1302 RTC** with CR2032 battery holder  
- **Power supervisor/reset (DS1233)**, **8 user LEDs**, **ON/OFF** and **RESET** switches  
- **Power input options**: barrel, screw terminal, or via serial/SPI/I²C headers  
- **Three BP80 sockets**: two vertical (S2/S3) + one horizontal (S1)

**Primary software**: **RomWBW** (CP/M 2.2, SD, RTC, CF), with the Small Computer Monitor (SCM) often stored in the 2nd ROM image.

---

## 2) Power & Firmware Selection

### 2.1 Powering the board
- 5 V DC via **J1 (barrel)**, **J2 (screw terminal)**, or **P10 (pre‑switch)**.  
- Either serial port can **provide or receive 5 V** if you fit **P4/P7** jumpers (one per port).  
- **Only one power source at a time** is recommended.  
- Typical current without accessories: ~**100 mA** (allow **300 mA**+ with modules).

### 2.2 Dual-Flash firmware arrangement
- Two 512 KB Flash devices (**U1**, **U2**). Only one is mapped at a time.  
- **JP3 or P9** selects the active ROM: **U1** (jumper/closed) or **U2** (open).  
- **Software selection** (JP3 “middle” position) is present but generally **not used**.  
- **Write‑protect** each ROM independently via **JP1 (U1)** and **JP2 (U2)**.

**Typical layout**: one ROM holds **RomWBW**, the other **SCM** (Small Computer Monitor).

---

## 3) On‑board Ports & Pinouts (all 5 V logic)

### 3.1 Serial (FTDI‑style 6‑pin, Port A on P5/P15; Port B on P6/P16)
Pin | Signal | Direction (w.r.t. SC126)
---|---|---
1 | GND | —
2 | RTS | Output
3 | +5 V | — (optional power)
4 | RXD | Input to CPU
5 | TXD | Output from CPU
6 | CTS | Input (**Port A only; B has no CTS**)

**Default baud**: **115200 8N1** on recent RomWBW; **38400** on very old pre‑3.0 builds. Hardware flow control is recommended.

### 3.2 SPI ports (6‑pin; P2/P12 and P3/P13)
Pin | Signal
---|---
1 | CS# (device select)
2 | SCK
3 | MOSI (master out)
4 | MISO (master in)
5 | +5 V
6 | GND

- Default SD card slot is **P2 (SPI SD Card 1)** with the common micro‑SD adapter.
- Many tiny SD adapters **do not tri‑state MISO**; use only **one** at a time in that case.

### 3.3 I²C (bit‑bang, 6‑pin; P1/P11)
Pin | Signal
---|---
1 | GND
2 | +5 V
3 | SCL
4 | SDA
5 | +5 V
6 | GND

- **JP5** can bridge I²C to the expansion bus USER pins: **SCL→USER6 (pin 78)**, **SDA→USER7 (pin 79)**.

---

## 4) Expansion Bus (80‑pin BP80, 3 sockets)

This is an **RC2014‑compatible** bus with a second row adding useful signals. Selected pins:

Row‑2 (#) | Signal | Row‑1 (#) | Signal
---|---|---|---
41 | — | 1 | A15
42 | — | 2 | A14
43 | — | 3 | A13
44 | — | 4 | A12
45 | — | 5 | A11
46 | — | 6 | A10
47 | — | 7 | A9
48 | — | 8 | A8
49 | A23 (n.u.) | 9 | A7
50 | A22 (n.u.) | 10 | A6
51 | A21 (n.u.) | 11 | A5
52 | A20 (n.u.) | 12 | A4
53 | A19 | 13 | A3
54 | A18 | 14 | A2
55 | A17 | 15 | A1
56 | A16 | 16 | A0
57 | GND | 17 | GND
58 | +5 V | 18 | +5 V
59 | RFSH | 19 | M1
60 | PAGE (n.u.) | 20 | RESET
61 | CLK2 (n.u.) | 21 | CLK
62 | BUSAK | 22 | INT
63 | HALT | 23 | MREQ
64 | BUSRQ | 24 | WR
65 | WAIT | 25 | RD
66 | NMI | 26 | IORQ
67 | D8 (n.u.) | 27 | D0
68 | D9 (n.u.) | 28 | D1
69 | D10 (n.u.) | 29 | D2
70 | D11 (n.u.) | 30 | D3
71 | D12 (n.u.) | 31 | D4
72 | D13 (n.u.) | 32 | D5
73 | D14 (n.u.) | 33 | D6
74 | D15 (n.u.) | 34 | D7
75 | TX2 | 35 | TX
76 | RX2 | 36 | RX
77 | USER5 | 37 | USER1
78 | USER6 (I²C SCL opt.) | 38 | USER2
79 | USER7 (I²C SDA opt.) | 39 | USER3
80 | USER8 (IEI) | 40 | USER4 (IEO)

> **Note:** USER4/USER8 are wired as a **Mode‑2 interrupt daisy chain** across sockets (not straight‑through).

---

## 5) Z180 & On‑board I/O Map

### 5.1 Memory map (physical)
- **0x00000–0x7FFFF** → **Flash ROM** (512 KB)  
- **0x80000–0xFFFFF** → **RAM** (512 KB)  
The Z180 MMU maps these into the 64 KB logical space used by Z80‑class code.

### 5.2 I/O addresses used by SC126
Port | Function
---|---
**0xC0–0xFF** | Z180 internal registers (ASCI, MMU, timers, etc.)
**0x0C** | **System latch** → controls RTC, SPI, I²C gating
**0x0D** | **LED data** → drives the 8 user LEDs

*All other I/O addresses are available to expansion modules.*

### 5.3 JP4 (DCD0/DREQ1)
- With some Z180s, **DCD0 must be pulled low** to enable serial receive. Fit the jumper.  
- DREQ1 is normally unused by most users but is brought out for experiments.

---

## 6) RomWBW on SC126 (CP/M, SD, RTC, CF)

- **Console** is **Serial Port A** (P5) by default.  
- **Baud**: RomWBW v3.x typically **115200 8N1**; early v2.x used **38400**.  
- **LEDs** show HBIOS init phases on boot.
- **RTC** is managed by **RTC.COM** (view with **T**, set with **I** then **S**).  
- **SD**: connect a micro‑SD adapter to **SPI SD Card 1 (P2)**. Partition/prepare with **FDISK80** (newer) or **CLRDIR** (older), then copy files.

**Example drive map (varies by build):**  
`A:=MD1:0  B:=MD0:0  C:..F:=IDE0:0..3  G:..J:=SD0:0..3`

---

## 7) Programming Cheats (8080/Z80 mnemonics)

### 7.1 Drive the on‑board LEDs (port 0x0D)
```asm
; Light all LEDs
    MVI  A,0FFH
    OUT  0DH

; Chase pattern
    MVI  A,01H
LOOP: OUT 0DH
      RLC
      JNC LOOP
      MVI A,01H
      JMP LOOP
```

### 7.2 Read RTC via RomWBW HBIOS (BCD YY,MM,DD,HH,MM,SS)
```asm
BDOS   EQU 5
RSTHB  EQU 8            ; RST 1 vector
RTCGET EQU 20H          ; HBIOS B=function code

        ORG 100H
        LXI  H,TIMBUF
        MVI  B,RTCGET
        RST  1           ; returns A=0 on success
        ; TIMBUF now has 6 BCD bytes (YY MM DD HH MM SS)
        RET

TIMBUF: DS 6
        END
```

### 7.3 BASIC quickies (SCM Basic / MBasic style)
```
OUT &HD, &H55      : REM LEDs = 01010101
OUT &HD, &HAA      : REM LEDs = 10101010
```

---

## 8) Assembly & Bring‑Up Highlights

- Solder passives, sockets, switch hardware per the **Assembly Guide**.  
- Use the guide’s **quick tests** (no shorts, LED test with U7 pins, reset voltage checks).  
- Fit **JP1/JP2** (write‑protect = safe), **JP4 DCD0** (receive enable), and your **ROM select** (JP3/P9).  
- Verify **oscillator X1 = 18.432 MHz** (matches standard ROMs).  
- Power on; confirm the **yellow power LED** and the **eight user LEDs** sequence with RomWBW.

---

## 9) Troubleshooting

Symptom | Checks
---|---
No serial output | Right port (P5), correct baud, GND alignment arrow, DCD0 jumper fitted
Boot loops / resets | 5 V within 4.75–5.25 V, DS1233 reset line high, no shorts
LEDs dead | OUT to 0x0D? Verify U7 pins and LED orientation, 470 Ω resistors fitted
SD not recognized | P2 used, single‑device MISO issue, use FDISK80/CLRDIR, correct wiring
RTC won’t hold time | Good CR2032, **Charge must be OFF** in RomWBW, set via RTC.COM
ROM select strange | JP3 vs P9 switch conflict; ensure one method only

---

## 10) Reference Drawings & Links (official)

- **SC126 overview & user guide hub** (power options, pinouts, bus map, jumpers, defaults)  
  https://smallcomputercentral.com/rcbus/sc100-series/sc126-z180-motherboard-rc2014/
- **Circuit explained** (I/O ports 0x0C/0x0D, LED latch, DS1302, decoders, oscillator)  
  https://smallcomputercentral.com/rcbus/sc100-series/sc126-z180-motherboard-rc2014/sc126-v1-0-circuit-explained/
- **Assembly guide** (parts, order, tests, photos)  
  https://smallcomputercentral.com/rcbus/sc100-series/sc126-z180-motherboard-rc2014/sc126-v1-0-assembly-guide-2/
- **RomWBW on SC126 (quick start / examples)**  
  https://smallcomputercentral.com/rcbus/sc100-series/sc126-z180-motherboard-rc2014/sc126-v1-0-software-romwbw/
- **SC126 kit sales pages** (specs snapshots)  
  https://www.tindie.com/products/tindiescx/sc126-z180-sbcmotherboard-kit-for-rcbus/  
  https://lectronz.com/products/sc126-rcbus-z180-sbcmotherboard-kit

---

## 11) Handy One‑Page Cheats

- **LED port**: `OUT 0x0D, value`  
- **System latch**: `OUT/IN 0x0C` (only if you know what you’re doing)  
- **Z180 internal regs**: `0xC0–0xFF`  
- **Default console**: Port **P5**, **115200 8N1** (RomWBW ≥3.x); **38400** on older builds  
- **RTC**: `RTC.COM` (T=show, I=set, S=commit; “Charge OFF”)  
- **SD**: micro‑SD on **P2**, prep with **FDISK80/CLRDIR**  
- **Power**: Choose **one** source; P4/P7 can back‑feed devices or power the board

---

### End of Manual
