Ports, Boards, and Code Notes
=============================

Boards
------

CPU/system board:
   SC722 Z180 CPU module with RomWBW / Z-System / ZSDOS.

LCD:
   SC719-style digital I/O LCD1602 interface.

Sensor:
   HWT905D TTL serial IMU connected to Serial Port B area.

Why 8080 ASM Syntax?
--------------------

The source uses CP/M ASM.COM compatible 8080 mnemonics:

   MVI A,055H
   LXI H,0000H
   CALL ROUT
   JMP LOOP

This runs on the Z80/Z180 because the Z80/Z180 runs 8080 code. It is not written in modern Z80 mnemonics such as LD/JR/DJNZ because the stock CP/M ASM.COM does not understand those.

LCD Port
--------

The LCD latch is:

   PORTLD EQU 000H

LCD functions in the source:

   LINI   initialize LCD
   LCLR   clear LCD
   LSET   set LCD DDRAM address
   LPUT   write 16 bytes
   LCMD   send LCD command
   LDAT   send LCD data

LCD bit map:

   bit 2 = RS
   bit 3 = E
   bit 4..7 = D4..D7

Serial Input
------------

Final working code does not directly read Z180 ASCI registers. It uses RomWBW HBIOS so RomWBW handles the hardware details.

Default serial unit:

   SELUNI DB 01H

Runtime unit select:

   0-7 keys select another HBIOS serial unit and reinitialize it.

HBIOS call trampoline:

   HBCL    DB 0CFH
           RET

0CFH is the 8080 opcode for RST 08H.

HBIOS serial functions used:

   B=00H  serial input
   B=02H  serial input status
   B=04H  serial init

The selected unit number is placed in C.

Serial Line Setup
-----------------

The program sets the selected HBIOS serial unit to:

   9600 baud, 8 data bits, no parity, 1 stop bit

In source:

   SER960 EQU 0703H

Packet Parser
-------------

The parser searches for HWT/WIT angle packets:

   55 53 d0 d1 d2 d3 d4 d5 d6 d7 sum

Parser state variables:

   PSTATE  current parser state
   PINDEX  index into FRAME
   PSUM    checksum accumulator
   FRAME   11-byte packet buffer

Only packet type 53H is used for the normal display.

Display Math
------------

HWT raw angle format is signed 16-bit scaled to +/-180 degrees. To avoid floating point, the source uses:

   degrees ~= ABS(raw) / 182

This is close enough for a 16x2 display and keeps the program ASM.COM-friendly.

Display Layout
--------------

Normal line templates:

   TPL1 = "   HDG 000 N   "
   TPL2 = " P+000 R+000 OK "

In REV4A, the top row was moved one position right after visual testing on the real LCD.

Final motion mapping:

   Field 1 -> PITCH
   Field 2 -> ROLL
   Field 3 -> YAW/HEADING
