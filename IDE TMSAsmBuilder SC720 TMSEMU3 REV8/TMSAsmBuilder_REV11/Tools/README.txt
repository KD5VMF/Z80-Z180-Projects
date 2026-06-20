Tools folder - REV11
====================

This folder contains the assembler used by the IDE.

Bundled tool:
  sjasmplus.exe

Default IDE args:
  --raw="{out}" "{src}"

Build output behavior:
  REV11 keeps the clean timestamped folder under Builds, containing:
    NAME.ASM
    NAME.HEX
    NAME.COM

Use the .COM for XMODEM transfer when programs are too large or annoying to paste as Intel HEX.

Upstream:
  https://github.com/z00m128/sjasmplus/releases/latest
