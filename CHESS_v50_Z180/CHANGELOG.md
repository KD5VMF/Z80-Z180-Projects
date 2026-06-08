# CHESS v50 Z180 Changelog


## CHESS50 CP/M ASM fix and no-loop refresh

- Fixed the CP/M ASM errors from `XRA MT` and the `ADC` label.
- Renamed the absolute-delta-column byte to `ACD` so CP/M ASM does not read it as an instruction.
- Replaced the invalid memory XOR with an 8080-safe register sequence.
- Kept the terminal cursor hidden while the game is running.
- Added a reverse-move blocker so a side will not make an empty move that simply backs up the exact move it just made.
- Changed the small tie-breaker to use the changing move sequence instead of only the game count, reducing repeated move loops.

## CHESS50 final repo naming refresh

- Renamed the project folder to `CHESS_v50_Z180`.
- Renamed the Black player source to `CHBLK50.ASM`.
- Renamed the White player source to `CHWHT50.ASM`.
- Updated all build/run text to use `CHBLK50` and `CHWHT50`.
- Updated the on-screen title bars to use the new chess-only names.
- Removed the old sensor-project prefix from the repo text and program display.
- Kept the ED-safe source size target below 1600 lines.
- Kept the alignment/balance refresh from v50.

## CHESS50 ED-safe thinking engine

- Replaced the large stored move list with live board scanning.
- Scans legal-looking board moves and scores candidates.
- Checks correct side, own-piece collision, pawn quiet/capture behavior, and sliding-piece paths.
- Scores capture value, center squares, useful piece movement, and side/game tie-breakers.
- Keeps the two-Z180 Port B packet link design.
- Keeps terminal BBS-style ANSI display.

## v50 final assembler top-border fix

- Shortened TOP border from 65 visible characters to 64.
- Fixes CP/M ASM `O` error on the TOP DB line.
- Keeps the aligned 64-column display box.
- Keeps hidden cursor and reverse-move loop blocker.
