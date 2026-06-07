# HWTLINK37 Pythagorean Port-B Link

Two Small Computer Central Z180 / RomWBW CP/M systems talking to each other over **Port B / HBIOS serial unit 1**, while each machine keeps **Port A** connected to its own Tera Term console.

This is the terminal-only, no-LCD, no-LED version based on the first confirmed working two-machine link engine from `HWTLINK30` and the stable Pythagorean test from `HWT36`.

## Hardware

Use a simple three-wire null-modem connection between the two Z180 systems:

```text
LEFT  TXB  -> RIGHT RXB
LEFT  RXB  -> RIGHT TXB
LEFT  GND  -> RIGHT GND
```

Do **not** connect 5V between boards. RTS/CTS are not used for this Port B link.

Each Z180 system also has its own terminal connected to Port A.

## Programs

```text
HWTWRK37.ASM  Worker, run first
HWTCTL37.ASM  Controller, run second
```

The controller sends `A` and `B` values. The worker calculates:

```text
A^2 + B^2 = C^2
```

The worker sends `C^2` back. The controller verifies the answer and sends OK/FAIL, then the next test runs forever.

## Build on CP/M

Copy the `.ASM` files to your CP/M disk, then build:

```text
ASM HWTWRK37
LOAD HWTWRK37

ASM HWTCTL37
LOAD HWTCTL37
```

## Run order

```text
1. Run HWTWRK37 first on the Worker system.
2. Run HWTCTL37 second on the Controller system.
```

## Serial settings

The program uses HBIOS serial unit 1 for the Port B link. It copies/uses the Port A line settings and is intended for:

```text
115200 8N1
```

The displayed line-character word should normally show:

```text
LC:3903
```

## Keys

```text
Q  Quit
R  Reset counters/state
I  Re-init Port B serial settings
A  Force/send from Controller
```

## Notes

This version is intentionally terminal-only:

```text
No LCD code
No LED code
No OUT DAH
Safe for SC131 and other systems without the SC719 I/O/LCD board
```

The important communication fix kept from the confirmed working baseline is: after a full packet is received and the state changes to transmit, the receive loop exits immediately so the program does not fall into one extra blocking receive attempt.
