# CHESS v50 Z180

CHESS v50 Z180 is a two-computer CP/M chess display and self-play project for Small Computer Central Z180 RomWBW systems. One Z180 runs the Black player, the other Z180 runs the White player, and the two machines communicate over Port B using a three-wire null-modem serial link. (Tested with z180 vs z180 and with the z80 vs z180 and works fine on the both, just slower on the z80 systems.)

## Files

| File | Purpose |
| --- | --- |
| `src/CHBLK50.ASM` | Black computer player. Run this first. |
| `src/CHWHT50.ASM` | White computer player. Run this second. |
| `BUILD_RUN.TXT` | Quick build and run commands. |
| `CHANGELOG.md` | Revision notes. |
| `docs/PACKET_FORMAT.TXT` | Simple Port B packet layout. |

## Hardware setup

Use two Z180 CP/M systems. Each system uses Port A for its own Tera Term console and Port B for the machine-to-machine chess link.

Port B wiring is null modem only:

```text
System 1 TXB  -> System 2 RXB
System 1 RXB  -> System 2 TXB
System 1 GND  -> System 2 GND
```

Do not connect 5V between the two machines. RTS/CTS hardware flow control is not used.

## Build

Copy the two ASM files from `src/` to the CP/M drive you want to build on.

On the Black system:

```text
A>ASM CHBLK50
A>LOAD CHBLK50
A>CHBLK50
```

On the White system:

```text
A>ASM CHWHT50
A>LOAD CHWHT50
A>CHWHT50
```

Run Black first, then run White.

## What v50 does

This version is still small enough for old CP/M editing limits, but it thinks harder than the earlier book-style versions. Instead of only stepping through a fixed move list, each side scans the board, tests candidate moves, scores them, and chooses the best move it finds.

The move chooser checks:

- the source square has one of its own pieces
- the target square is not occupied by its own side
- pawn quiet moves land on empty squares
- pawn captures hit the other side
- bishop, rook, and queen paths are clear
- pawn promotion to queen

The move chooser scores:

- capture value
- center control
- useful piece movement
- move-number tie-breakers and a reverse-move blocker so games are more interesting to watch

This is not a full tournament chess engine. It is a watchable two-machine CP/M chess project that fits inside tight source-size limits and runs on vintage hardware. The v50 refresh also avoids the simple back-and-forth move loop that can happen when both sides keep chasing the same position.

## Display

The screen is a BBS-style ANSI terminal display. It hides the terminal cursor while running and shows the board, side status, packet counts, good/bad packets, resends, current move, score, and total wins.

Keys:

```text
Q  quit
R  reset
I  init
A  resend
```

## Source limits

The ASM files are intentionally plain CP/M assembler source with no explanatory comment lines. This keeps them easier to paste and edit on old systems. The v50 source stays under the 1600-line ED safety target.

Expected line counts:

```text
CHBLK50.ASM  1587 lines
CHWHT50.ASM  1599 lines
```

## Notes

The two machines do not need Internet, filesharing, or a modern host once the programs are copied and built. Watching two Z180 CP/M systems pass chess moves over a simple serial link is the whole point of the project.

## Final assembler note

The TOP DB border was shortened to 64 visible characters so CP/M ASM does not flag an `O` error on the border string. The display remains aligned to the 64-column text box.
