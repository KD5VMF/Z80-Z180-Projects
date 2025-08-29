
# RomWBW HBIOS + CP/M 2.2 BDOS — Practical Programmer’s Manual

**Target audience:** 8080/Z80 assembly programmers using RomWBW (e.g., RC2014/RCBus/RetroBrew) under CP/M 2.2/Z-System.  
**Status:** Community reference, compiled from RomWBW docs and classic CP/M manuals.  
**Tested against:** RomWBW 3.x (concepts unchanged across recent versions).  
**License:** You may copy and share this file.

---

## Contents

1. [What RomWBW is](#what-romwbw-is)  
2. [Memory layout & HBIOS proxy](#memory-layout--hbios-proxy)  
3. [HBIOS: how to call it (RST 08h)](#hbios-how-to-call-it-rst-08h)  
4. [Character I/O (CIO) API](#character-io-cio-api)  
5. [Disk I/O (DIO) API](#disk-io-dio-api)  
6. [Real‑Time Clock (RTC) API](#real-time-clock-rtc-api)  
7. [Video Display Adapter (VDA) API](#video-display-adapter-vda-api)  
8. [System (SYS) services](#system-sys-services)  
9. [CP/M 2.2 BDOS: calling convention & complete function list](#cpm-22-bdos-calling-convention--complete-function-list)  
10. [Worked examples (8080 mnemonics)](#worked-examples-8080-mnemonics)  
11. [Useful ROMWBW commands (MODE, XM, etc.)](#useful-romwbw-commands-mode-xm-etc)  
12. [Troubleshooting & gotchas](#troubleshooting--gotchas)  
13. [Further reading & canonical sources](#further-reading--canonical-sources)

---

## What RomWBW is

RomWBW is a full firmware image for Z80/Z180/Z280 class systems that bundles:
- Boot loader and monitor
- **HBIOS** (Hardware BIOS) with drivers for serial, disk, RTC, video, etc.
- A full OS image (typically **CP/M 2.2** or **ZSDOS/Z-System**)
- ROM and RAM disk images

HBIOS gives the OS a consistent driver interface while keeping most code out of the 64K TPA via **bank‑switching**.

---

## Memory layout & HBIOS proxy

RomWBW maps a tiny **HBIOS proxy** stub at the **top 512 bytes** of the 64K space. Applications and the OS call into HBIOS through this proxy; the proxy swaps in the driver bank, runs the service, then restores the original mapping.

**High‑level picture (not to scale):**

```
0000 ─────────────────────────────────────────────────────────────────
      (bank‑switched lower 32K: app/OS/CBIOS etc.)
8000 ─────────────────────────────────────────────────────────────────
      (fixed upper 32K: includes HBIOS proxy area at the very top)
FE00 ─────────────── HBIOS proxy (RST 08h entry lives here) ──────────
FFFF ─────────────────────────────────────────────────────────────────
```

Implications:
- Some HBIOS calls require buffers to be in the **upper 32K** (e.g., disk and NVRAM block transfers).
- Don’t nest HBIOS calls from inside HBIOS (drivers call each other directly instead).

---

## HBIOS: how to call it (RST 08h)

**Invocation pattern (8080 mnemonics):**
- Put the **function code** in **B**
- Often put a **unit number or subfunction** in **C**
- Put any **pointer** in **HL**, byte args in **D/E** as specified
- Execute **`RST 1`** (vector **0008h**)
- **A** returns **status**: **0 = success**, non‑zero = error (meaning is function‑specific)
- HBIOS preserves only what it must; assume non‑mentioned registers may be clobbered

**Example skeleton:**
```asm
; Call HBIOS function in B, parameters in C/DE/HL as required
        MVI  B,0x20       ; example: RTCGETTIM
        LXI  H,TIMBUF     ; buffer in upper 32K when required
        RST  1            ; HBIOS entry at 0008h
        ORA  A            ; A=0 => OK
        JNZ  HB_ERR
```

**Unit numbers** (C) are **assigned dynamically at boot** and printed by RomWBW during device discovery. For many CIO calls you can use **C = 80h** to mean “current console.”

---

## Character I/O (CIO) API

You select a serial/console **unit** in **C** and call with the **B** function:

| B     | Name               | In regs                  | Returns                  | Notes |
|------:|--------------------|--------------------------|--------------------------|------|
| 00h   | **CIOIN**          | C=unit                   | A=status, **E=char**     | Blocking read |
| 01h   | **CIOOUT**         | C=unit, **E=char**       | A=status                 | Blocking write |
| 02h   | **CIOIST**         | C=unit                   | **A=bytes** available    | 0/1 acceptable if no buffer |
| 03h   | **CIOOST**         | C=unit                   | **A=space** in out buf   | 0/1 acceptable if no buffer |
| 04h   | **CIOINIT**        | C=unit, **DE=line word** | A=status                 | Set baud/framing; DE=-1 reinit previous |
| 05h   | **CIOQUERY**       | C=unit                   | A=status, **DE=line**    | Get current line settings |
| 06h   | **CIODEVICE**      | C=unit                   | A=status, C=attrib, D=type, E=phys | Driver/type info |

**Line word (DE)** bits (typical): DTR/RTS, XON/XOFF, parity, stop bits, data bits, **baud field** (5 bits, V = 75×2^X×3^Y).

---

## Disk I/O (DIO) API (selected)

| B     | Name          | In regs                                | Returns                 |
|------:|---------------|----------------------------------------|-------------------------|
| 10h   | **DIOSTATUS** | —                                      | A=status                |
| 11h   | **DIORESET**  | C=unit                                 | A=status                |
| 12h   | **DIOSEEK**   | C=unit, D7=mode, if CHS: D=head,E=sec,HL=trk; if LBA: DE:HL=block | A=status |
| 13h   | **DIOREAD**   | C=unit, E=blocks, **HL=buffer**        | A=status, E=read count  |
| 14h   | **DIOWRITE**  | C=unit, E=blocks, **HL=buffer**        | A=status, E=written     |
| 18h   | **DIOMEDIA**  | C=unit, E0 bit0 = probe                | A=status, E=Media ID    |
| 1Ah   | **DIOCAPACITY** | C=unit, **HL=buffer**                | A=status, **DE:HL=blocks**, **BC=blk size** |
| 1Bh   | **DIOGEOMETRY** | C=unit                               | A=status, HL=cyl, D7=LBA?, BC=blk size |

*Buffers for disk I/O must be in upper 32K.*

---

## Real‑Time Clock (RTC) API

**Time buffer:** 6 bytes **BCD**:  
`[0]=YY  [1]=MM  [2]=DD  [3]=HH  [4]=MM  [5]=SS`

| B     | Name          | In regs        | Returns     |
|------:|---------------|----------------|-------------|
| 20h   | **RTCGETTIM** | **HL=buffer**  | A=status    |
| 21h   | **RTCSETTIM** | **HL=buffer**  | A=status    |
| 22h   | RTCGETBYT     | C=index        | A=status, **E=value** |
| 23h   | RTCSETBYT     | C=index, **E=val** | A=status |
| 24h   | RTCGETBLK     | **HL=buffer**  | A=status    |
| 25h   | RTCSETBLK     | **HL=buffer**  | A=status    |

*For the NVRAM block (24h/25h), the buffer must be in the upper 32K.*

---

## Video Display Adapter (VDA) API (selected)

- Unified interface for on‑board VDUs (SY6545, MC8563, TMS9918, uPD7220, etc.)
- **Color byte** uses RGBI bits: low nibble = foreground, high nibble = background (I/B/G/R).

Keyboard functions on VDA: status (4Ch), flush (4Dh), read (4Eh) returning scancode, keystate flags, and ASCII when applicable.

---

## System (SYS) services

| B     | Name         | In regs                   | Returns                        |
|------:|--------------|---------------------------|--------------------------------|
| F0h   | **SYSRESET** | —                         | A=status                       |
| F1h   | **SYSVER**   | —                         | A=status, **DE=ver (maj/min/patch/build)**, **L=platform ID** |
| F2h   | **SYSSETBNK**| C=bank                    | A=status, **C=prev bank**      |
| F3h   | **SYSGETBNK**| —                         | A=status, **C=active bank**    |
| F4h   | **SYSSETCPY**| D=dest bank, E=src bank, **HL=bytes** | A=status            |
| F5h   | **SYSBNKCPY**| **DE=dest addr, HL=src addr**          | A=status            |
| F6h   | **SYSALLOC** | **HL=size**               | A=status, **HL=addr in HBIOS heap** |
| F7h   | **SYSFREE**  | **HL=addr**               | A=status (not yet implemented) |
| F8h   | **SYSGET**   | **C=subfunc**             | A=status, various (see below)  |

**SYSGET subfunctions (C):**
- 00h: **CIOCNT** → E=count of serial units  
- 10h: **DIOCNT** → E=count of disk units  
- 40h: **VDACNT** → E=count of video units  
- D0h: **TIMER** → DE:HL = tick count  
- D1h: **SECONDS** → DE:HL = seconds since boot; C=ticks within current second  
- E0h: **BOOTINFO** → L = boot bank ID

---

## CP/M 2.2 BDOS: calling convention & complete function list

**How to call from 8080/Z80:**

```asm
; BDOS function call (CP/M 2.2)
; C = function number
; DE = parameter (address or immediate), if any
; returns: A for 8‑bit, or HL for 16‑bit values (convention varies by func)

        MVI  C,9          ; print string
        LXI  D,MSG$       ; $-terminated
        CALL 5
```

**Register safety:** BDOS may clobber registers; save what you need.

**Common console I/O:**
- 1 **Console Input** → A = char
- 2 **Console Output** (E = char)
- 6 **Direct Console I/O** (E=FFh status / FEh input / FDh output / or E=char)

**Disk & files:** 13 Reset, 14 Select, 15 Open, 16 Close, 20 Read Seq, 21 Write Seq, 33 Read Rand, 34 Write Rand, 35 File Size, 36 Set Rand Rec, 40 Write Rand with Zero Fill, etc.

**Full CP/M 2.2 list (0..47 with later extensions) and parameter rules are included below for quick lookup.**

<details>
<summary>CP/M 2.2 BDOS function summary (short table)</summary>

```
00 System Reset
01 Console Input                -> A=char
02 Console Output    E=char
03 Auxiliary Input              -> A=char
04 Auxiliary Output  E=char
05 List Output       E=char
06 Direct Console I/O E=FF/FE/FD/char -> A=char/status
07 Get IOBYTE                   -> A
08 Set IOBYTE       E=iobyte
09 Print String     DE=.str ($-terminated)
10 Read Console Buffer DE=.buf
11 Get Console Status           -> A=00/01
12 Return Version               -> HL
13 Reset Disk System
14 Select Disk      E=disk (0=A)
15 Open File        DE=.FCB    -> A=dir code
16 Close File       DE=.FCB    -> A=dir code
17 Search First     DE=.FCB    -> A=dir code
18 Search Next                 -> A=dir code
19 Delete File      DE=.FCB    -> A=dir code
20 Read Sequential  DE=.FCB    -> A=err
21 Write Sequential DE=.FCB    -> A=err
22 Make File        DE=.FCB    -> A=dir code
23 Rename File      DE=.FCB    -> A=dir code
24 Return Login Vector         -> HL
25 Return Current Disk         -> A
26 Set DMA Address  DE=.dma
27 Get Addr (Alloc)           -> HL
28 Write Protect Disk
29 Get R/O Vector             -> HL
30 Set File Attributes DE=.FCB -> A=dir code
31 Get Addr (DPB)             -> HL
32 Set/Get User Code E=FF/user -> A=current user
33 Read Random      DE=.FCB    -> A=err
34 Write Random     DE=.FCB    -> A=err
35 Compute File Size DE=.FCB   -> r0,r1,r2 in FCB
36 Set Random Record DE=.FCB   -> r0,r1,r2 in FCB
37 Reset Drive      DE=drive vector -> A=err
40 Write Rand w/ ZF DE=.FCB    -> A=err
...
```
</details>

> Tip: For **non‑blocking key poll** use BDOS 6 with **E=0FFh** (status) → A=00/FF. For **string output** (BDOS 9), terminate with `$`.

---

## Worked examples (8080 mnemonics)

### 1) Print “Hello, world”
```asm
        ORG 100H
        MVI  C,9
        LXI  D,MSG
        CALL 5
        RET
MSG:    DB  'Hello, world!$'
```

### 2) Read RomWBW RTC and print `YYYY-MM-DD HH:MM:SS`
```asm
BDOS    EQU 5
CONOUT  EQU 2
        ORG 100H

START:  ; get time from HBIOS
        LXI  H,TIMBUF
        MVI  B,20H          ; RTCGETTIM
        RST  1
        ORA  A
        JNZ  DONE

        ; print "20"
        MVI  E,'2'          ; BDOS char out helper
        CALL PCHAR
        MVI  E,'0'
        CALL PCHAR

        ; YY MM DD HH MM SS (BCD)
        LDA  TIMBUF+0
        CALL P2DIG
        MVI  E,'-'
        CALL PCHAR
        LDA  TIMBUF+1
        CALL P2DIG
        MVI  E,'-'
        CALL PCHAR
        LDA  TIMBUF+2
        CALL P2DIG
        MVI  E,' '
        CALL PCHAR
        LDA  TIMBUF+3
        CALL P2DIG
        MVI  E,':'
        CALL PCHAR
        LDA  TIMBUF+4
        CALL P2DIG
        MVI  E,':'
        CALL PCHAR
        LDA  TIMBUF+5
        CALL P2DIG
        MVI  E,13
        CALL PCHAR
        MVI  E,10
        CALL PCHAR
DONE:   RET

; ---- helpers ----
; print char in E via BDOS 2
PCHAR:  MVI  C,CONOUT
        CALL BDOS
        RET

; A (BCD) -> print two ASCII
P2DIG:  CALL BCD2HL
        MOV  E,H
        CALL PCHAR
        MOV  E,L
        CALL PCHAR
        RET

; A (BCD) -> H=tens ASCII, L=ones ASCII
BCD2HL: MOV  D,A
        ANI  0FH
        ADI  '0'
        MOV  L,A
        MOV  A,D
        ANI  0F0H
        RRC
        RRC
        RRC
        RRC
        ADI  '0'
        MOV  H,A
        RET

TIMBUF: DS   6
        END  START
```

### 3) Change COM0 to 9600,N,8,1 using CIOINIT
```asm
; Get current line settings, modify just the baud field, re-init
; (Exact line-word encoding is device/driver specific; MODE.COM is the
; easier user-facing way. Example here illustrates CIO pattern.)

        MVI  B,05H      ; CIOQUERY
        MVI  C,80H      ; current console
        RST  1
        XCHG            ; DE now holds line word in HL for edits (example)
        ; ... patch baud bits to desired value ...
        ; write back:
        MVI  B,04H      ; CIOINIT
        MVI  C,80H
        XCHG            ; HL->DE
        RST  1
```

---

## Useful ROMWBW commands (MODE, XM, etc.)

- **`MODE`** — List/set serial parameters at runtime.  
  Examples:
  ```
  A>MODE              ; show current ports and settings
  A>MODE COM0: 9600,N,8,1
  A>MODE COM1: 115200,N,8,1
  ```
  If you see **“Invalid device configuration specified”**, the tuple isn’t supported by the underlying driver or device. Use `MODE` with a full tuple (`baud,parity,data,stop`) for best results.

- **`XM`** — XMODEM file transfer.  
  Examples:
  ```
  A>XM R FILE.COM     ; receive FILE.COM
  A>XM S FILE.COM     ; send FILE.COM
  ```
  Use your terminal’s **XMODEM/CRC** at the same serial speed shown by `MODE`.

---

## Troubleshooting & gotchas

- **Unit numbers** are assigned **dynamically** at boot; don’t hardcode. Use console alias **C=80h** where supported.
- **Buffers in upper 32K**: for disk I/O and RTC NVRAM block, allocate buffers above 8000h.
- **Bank operations (SYSSETBNK/SYSBNKCPY)** are powerful but dangerous. Ensure code & stack are in upper 32K when switching banks.
- **ANSI/TTY**: When writing to the CRT device (CIO) you pass through an emulator; initialize VDA/EMU layers if addressing the video device directly.

---

## Further reading & canonical sources

- **RomWBW Architecture & HBIOS Reference** (official):  
  Section *8.1 Invocation*, *8.2 CIO*, *8.3 DIO*, *8.4 RTC*, *8.5 VDA*, *8.6 SYS*.  
  https://retrobrewcomputers.org/ (RomWBW Architecture PDF)

- **RomWBW GitHub (latest docs & releases)**:  
  https://github.com/wwarthen/RomWBW

- **CP/M BDOS function reference** (CP/M 2.2):  
  https://www.seasip.info/Cpm/bdos.html (concise), plus classic manuals (Digital Research CP/M 2.2 System Manual).

- **Small Computer Central: RomWBW how‑tos & MODE usage**:  
  https://smallcomputercentral.com/romwbw/

---

## Appendix: CP/M 2.2 BDOS — function details

Below is a compact “programmer’s card” derived from CP/M 2.2 references. Parameters are **C=function**, **DE=param** unless noted. Returns in **A** (8‑bit) or **HL** (16‑bit). Use **CALL 5**.

```
00 System Reset
01 Console Input                         -> A=char
02 Console Output           E=char
03 Auxiliary (Reader) Input              -> A=char
04 Auxiliary (Punch) Output E=char
05 List Output               E=char
06 Direct Console I/O        E=FF/FE/FD/char -> A=char/status
07 Get IOBYTE                             -> A=IOBYTE
08 Set IOBYTE                E=IOBYTE
09 Print String              DE=.str ($-terminated)
10 Read Console Buffer       DE=.buf (1st byte = length on entry; buf[1] = actual on return)
11 Get Console Status                      -> A=00/01
12 Return Version Number                    -> HL
13 Reset Disk System (flush, relogin)
14 Select Disk                E=disk (0=A)
15 Open File                 DE=.FCB      -> A=dir code
16 Close File                DE=.FCB      -> A=dir code
17 Search for First          DE=.FCB      -> A=dir code
18 Search for Next                         -> A=dir code
19 Delete File               DE=.FCB      -> A=dir code
20 Read Sequential           DE=.FCB      -> A=err (00 ok, 01 EOF)
21 Write Sequential          DE=.FCB      -> A=err
22 Make File                 DE=.FCB      -> A=dir code
23 Rename File               DE=.FCB      -> A=dir code
24 Return Login Vector                      -> HL (bitmask of logged-in drives)
25 Return Current Disk                      -> A (0=A)
26 Set DMA Address           DE=.dma
27 Get Addr (Alloc)                          -> HL (allocation vector)
28 Write Protect Disk (current)
29 Get R/O Vector                            -> HL
30 Set File Attributes        DE=.FCB      -> A=dir code
31 Get Addr (DPB)                             -> HL
32 Set/Get User Code          E=FF/get else set -> A=current user
33 Read Random               DE=.FCB       -> A=err
34 Write Random              DE=.FCB       -> A=err
35 Compute File Size         DE=.FCB       -> r0,r1,r2 in FCB
36 Set Random Record         DE=.FCB       -> r0,r1,r2 in FCB
37 Reset Drive               DE=drive bitmask -> A=err
40 Write Random w/ Zero Fill DE=.FCB       -> A=err
```

For exact semantics and error codes, see the Digital Research manuals.

---

*End of manual.*
