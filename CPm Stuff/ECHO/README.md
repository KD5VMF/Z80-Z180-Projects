# LEDLAB10 + ECHO (SC719 Parallel Art + Repeater)
**SC719 parallel LED art + hardware echo for SC700‑series Z80/Z180 systems (CP/M + RomWBW)**

https://youtu.be/DWX6Oos8JMU?feature=shared

![badge](https://img.shields.io/badge/Target-CP%2FM-0366d6)
![badge](https://img.shields.io/badge/CPU-8080%2FZ80-blue)
![badge](https://img.shields.io/badge/RomWBW-HBIOS-brightgreen)
![badge](https://img.shields.io/badge/Module-SC719%20Digital%20I%2FO-orange)

```
   _      _____  ____  _   _  _           ____  _  _  ___
  | |    | ____|/ ___|| | | || |         |___ \| || ||__ \
  | |    |  _|  \___ \| | | || |   _____   __) | || |_  ) |
  | |___ | |___  ___) | |_| || |__|_____| / __/|__   _/ / 
  |_____||_____||____/ \___/ |_____|     |_____|  |_||____|
      SC719 LED “art” + instant parallel echo (D0..D7)
```

## ✨ What is this?
- **`basic/LEDDLAB10.BAS`** — MBASIC LED art generator for **SC719** Digital I/O (Port **0x30 / 48**).
- **`asm/ECHOMIR.ASM` → `bin/ECHOMIR.COM`** — ultra‑fast **mirror** echo: copies every bit from input pins **directly** to outputs (no protocol).
- **`asm/ECHOINV.ASM` → `bin/ECHOINV.COM`** — same as above but **inverts** the received value before output (configurable mask).

Wire **two** SC719 boards together (D0..D7 + GND). Run **LEDDLAB10** on one machine (“Art”) and **ECHOMIR** (or **ECHOINV**) on the other (“Echo”). The Echo box becomes a **repeater**—it reproduces whatever the Art box outputs, in real time.

> Target: **SC700‑series** (e.g., **SC126**, **SC131**) + **RomWBW HBIOS** + **CP/M** (BASIC‑80 & ASM/LOAD).

---

## 🔌 Hardware
- Two SCC machines with **SC719** Digital I/O installed.
- Both SC719s set to **the same I/O base** (default here **0x30** / dec **48**; set via **JP1** on SC719).
- Cable the ports one‑to‑one + ground:

```
SC719 #1              SC719 #2
----------            ----------
D0  ----------------  D0
D1  ----------------  D1
D2  ----------------  D2
D3  ----------------  D3
D4  ----------------  D4
D5  ----------------  D5
D6  ----------------  D6
D7  ----------------  D7
GND ----------------  GND
```

> Keep the cable short. Tie GND↔GND (multiple grounds recommended).

---

## 🧠 How it works
- `LEDDLAB10.BAS` drives **D0..D6** with smooth, stable frames (no forced zero between frames).
- `ECHOMIR.COM` loops: `OUT <= (IN ^ IN_INV) ^ OUT_INV` — **mirrors all 8 bits** instantly.
- `ECHOINV.COM` loops: `OUT <= ((IN ^ IN_INV) ^ INV_MASK) ^ OUT_INV` — same but **inverts** a mask (default all 8 bits).

This makes the second system a **hardware repeater**: same LEDs, timing, and patterns mirrored (or inverted) on another board.

---

## ⚙️ Software setup

### 1) Build the echo (optional if you have COMs)
Assemble on CP/M:
```text
A>ASM ECHOMIR
A>LOAD ECHOMIR
A>ASM ECHOINV
A>LOAD ECHOINV
```
Then run either:
```text
A>ECHOMIR
; or
A>ECHOINV
```

### 2) Run the art
Load `LEDDLAB10.BAS` in MBASIC on the **Art** machine and `RUN`.

### 3) Watch the mirror
Run the chosen echo COM on the **Echo** machine. It has no UI and doesn’t exit; warm‑boot to stop.

---

## 🛠️ Configuration (port & polarity)
Both programs assume **Port 0x30 (48)** and **active‑high** wiring.

- Change **port**:  
  - BASIC: set `PO=48` near the top of `LEDDLAB10.BAS`.  
  - ASM: set `DIO_PORT EQU 030H` in `ECHOMIR.ASM` / `ECHOINV.ASM` and re‑assemble.
- Handle **active‑low**:
  - BASIC: set `IV=255`.  
  - ASM: adjust at the top:
    ```asm
    ; incoming looks inverted?
    IN_INV   EQU 000H   ; -> set to 0FFH

    ; LEDs are active-low?
    OUT_INV  EQU 000H   ; -> set to 0FFH
    ```
- For `ECHOINV.ASM`, choose what to invert:
  ```asm
  INV_MASK  EQU 0FFH    ; invert ALL 8 bits (D0..D7) [default]
  ;INV_MASK EQU 07FH    ; invert only D0..D6, leave D7 unchanged
  ```

---

## 🧪 Quick sanity test
On the **Art** machine (MBASIC):
```basic
10 DEFINT A-Z: PO=48: IV=0
20 FOR B=1 TO 127
30  IF IV=255 THEN OUT PO,255-B ELSE OUT PO,B
40  FOR D=1 TO 800: NEXT D
50 NEXT B
60 GOTO 20
```
On the **Echo** machine run `ECHOMIR` (or `ECHOINV`). You should see the same (or inverted) walking‑dot pattern on both systems.

---

## 🐞 Troubleshooting
- **No LEDs on Echo**: verify GND↔GND, same port, try inversion (`IV=255` in BASIC; `OUT_INV/IN_INV=0FFH` in ASM).
- **Some bits missing**: check each D0..D7 line continuity.
- **Feedback / lockup**: don’t run echo on *both* ends simultaneously.
- **Choppy art**: reduce dwell in LEDLAB10 and avoid clearing to 0 between frames.

---

## 📜 License
MIT (or your preferred license).

---

## 🙌 Credits
- Small Computer Central **SC700‑series** + **SC719** Digital I/O  
- **RomWBW HBIOS** for making CP/M shine on modern homebrew SBCs  
- **MBASIC** + **ASM/LOAD** toolchain
