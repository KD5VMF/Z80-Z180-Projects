# HWTCHESS49 - Two Real Z180 Computers Playing Chess Over Port B           (I have tested this with the Z80 vs the Z180 and it works fine. It is slower of course but neat!)

HWTCHESS49 is a **two-computer, computer-vs-computer chess demonstration** for **Small Computer Central Z180 RomWBW CP/M systems**.

This is not one computer simulating both sides. It is **two separate Z180 computers**, each with its own terminal on **Port A**, talking directly to each other over **Port B** with a simple **three-wire null-modem link**. One system runs the **Black computer** and the other runs the **White computer**. Each machine keeps its own local board, its own counters, and its own display, while move packets travel over the serial link.

The result is a very old-school but very real distributed game: **one physical computer vs another physical computer**.

---

## What is in this repo

| File | What it is |
| --- | --- |
| `src/HWTBLK49.ASM` | Black computer player. **Run this first.** |
| `src/HWTWHT49.ASM` | White computer player. **Run this second.** White still makes the first move. |
| `BUILD_RUN.TXT` | Quick build and run notes |
| `docs/PACKET_FORMAT.TXT` | Brief packet layout |
| `CHANGELOG.md` | Revision summary |

---

## Target hardware

This project was built for **Small Computer Central Z180 RomWBW CP/M systems**, especially setups like:

- **SC131** Z180 Pocket Computer
- Other Small Computer Central / RCBus Z180 systems using **RomWBW**
- Systems where **Port A** is the local terminal console and **Port B** is available as a second serial port

The demonstrated working setup was:

- **One Z180 per side**
- **Each Z180 Port A** connected to its own terminal window (for example Tera Term)
- **Each Z180 Port B** connected to the other Z180 Port B
- **RomWBW HBIOS serial unit 1** used for the link

---

## Wiring the two computers together

Use a **3-wire null modem** only:

```text
LEFT  TXB  -> RIGHT RXB
LEFT  RXB  -> RIGHT TXB
LEFT  GND  -> RIGHT GND
```

Do **not** connect 5V between the boards.

Do **not** use RTS/CTS for this project.

This project was developed around the fact that the Z180 Port B link is working fine with:

- TX
- RX
- GND

That simple three-wire setup is enough for the proven link engine used here.

---

## Why this is neat

It is easy to forget how much is going on here because the screen looks calm and clean.

Each Z180 is doing all of this at once:

- maintaining a full chess board in RAM
- drawing a flicker-controlled ANSI terminal display
- polling the keyboard
- polling HBIOS serial status
- receiving and parsing packets
- generating outgoing move packets
- updating counters and tournament totals
- coordinating game reset / new-game state
- choosing moves from a small move-book / demo engine

And this is happening on **real CP/M-era style hardware**, not under a modern OS scheduler and not in a giant software stack.

That is what makes it fun: these are **two genuinely independent old computers** playing against each other over a wire.

---

## Serial setup

The programs use **RomWBW HBIOS serial unit 1** for the inter-computer link.

They copy the active console line settings and initialize Port B to match. On the working systems used here, that means:

```text
115200 baud, 8 data bits, no parity, 1 stop bit
```

Port A remains the console terminal for each machine.

---

## Correct run order

For this revision, the correct startup order is:

```text
1. Run HWTBLK49 first on the Black computer.
2. Run HWTWHT49 second on the White computer.
```

Black starts in receive/listen mode.
White is started second, but White still makes the **first chess move**.

---

## Building on CP/M

### If the source files are already on disk

On the Black computer:

```text
A>ASM HWTBLK49
A>LOAD HWTBLK49
A>HWTBLK49
```

On the White computer:

```text
A>ASM HWTWHT49
A>LOAD HWTWHT49
A>HWTWHT49
```

---

## Getting the files onto the machines with ED

If you want to enter or paste the source using **CP/M ED**, here is a simple practical workflow.

### 1) Create the file in ED

Example for the Black side:

```text
A>ED HWTBLK49.ASM
```

Example for the White side:

```text
A>ED HWTWHT49.ASM
```

### 2) Enter insert mode

Inside ED, use:

```text
I
```

Then paste or type the source text.

### 3) End insert mode

When done entering text, press **Ctrl+Z** on its own line.

### 4) Write the file

In ED, write the file out:

```text
E
```

That saves and exits.

### Notes about ED and old CP/M tools

- Keep filenames **8.3-style**.
- Avoid giant unbroken source lines.
- In particular, very long `DB` string lines can make old CP/M assemblers unhappy.
- That is why these sources split longer border strings into multiple `DB` lines.

If you are using Tera Term to paste into ED, slower pasting may help on some systems.

---

## What each computer is really doing

### Black computer (`HWTBLK49`)

- starts first
- initializes the local board
- waits in receive mode for White's first move
- when a move packet arrives, Black:
  - validates the packet
  - applies the move locally
  - updates its display
  - chooses a reply move
  - sends the reply packet back to White

### White computer (`HWTWHT49`)

- starts second
- initializes the local board
- creates the first move
- sends the first move packet
- then waits for Black's reply
- when Black replies, White:
  - validates the packet
  - applies the move locally
  - updates its display
  - chooses the next White move
  - sends it back

That back-and-forth continues for the whole game.

When a game ends or the demo move-book is exhausted, the software coordinates a **new synchronized game** so both machines reset together.

---

## Packet format

The link uses a short 9-byte packet structure descended from the known-good HWTLINK30 / HWTLINK37 communication engine.

Conceptually it is:

```text
55 AA TYPE SEQ FROM TO PIECE BOARDCHK CHECKSUM
```

Typical meanings:

- `55 AA` = packet sync bytes
- `TYPE` = move / new game / control type
- `SEQ` = move sequence number
- `FROM` = source square
- `TO` = destination square
- `PIECE` = moving piece
- `BOARDCHK` = simple board check / XOR byte
- `CHECKSUM` = packet checksum

The receiver does not blindly block waiting forever for random input. Instead it follows the proven pattern:

- poll receive status first
- only read when data is present
- parse the packet byte by byte
- when parsing changes the state to transmit, **exit the RX loop immediately**

That last behavior was the key fix that made the two Z180 machines communicate reliably.

---

## Screen / terminal behavior

This revision focuses on a **BBS-style ANSI screen**:

- cursor hidden while the program runs
- static frame drawn once
- live fields updated in place
- no full-screen redraw every cycle
- colorful but readable terminal look

For best results use a terminal that handles ANSI cursor positioning well, such as **Tera Term**.

---

## Keyboard controls

```text
Q = quit back to CP/M
R = reset program state
I = reinitialize the Port B serial unit
A = resend / force transmit
```

---

## What the screen fields mean

### Board area

Shows the local copy of the chess board on that machine.

### Phase
n
A small internal state indicator, for example receive / transmit / gap.

### SendSeq / RecvSeq

Shows outgoing and last received sequence numbers.

### Move / Piece

Shows the move currently being sent or most recently processed.

### Packets TX / RX

How many whole packets this machine has transmitted and received.

### Bytes TX / RX

How many raw serial bytes have been sent and received.

### Good / Bad / Miss / Retry

- **Good** = valid packets or accepted operations
- **Bad** = checksum or invalid packet problems
- **Miss** = state mismatch / synchronization mismatch counters
- **Retry** = retry activity

### Total games / W wins / B wins

Tournament-style totals since start/reset.

---

## Why the project matters

A lot of retro demos only prove that an old machine can do one thing alone.
This project proves something more interesting:

- two separate old Z180 systems can be linked directly
- each can maintain its own local state
- they can stay synchronized over a serial protocol
- they can present their own live status UIs
- and they can cooperate / compete in a continuous loop

That is why this is more than just a chess demo. It is also a **distributed systems demo on vintage-style hardware**.

---

## Revision notes for HWTCHESS49

REV49 keeps the proven working function from REV48 and concentrates on presentation polish:

- improved ANSI / BBS-style color presentation
- cursor hidden during runtime
- prettier static frame
- same proven link and board-sync engine
- terminal only, no LCD, no LED I/O, no `OUT DAH`

---

## Final note

This is intentionally not a giant modern chess engine. It is a compact, understandable, serial-linked, two-machine Z180 demo built to run in the constraints of old CP/M systems.

That is exactly what makes it cool.
