Tools folder
============

This folder contains the assembler used by the IDE.

Bundled tool:
  sjasmplus.exe

The IDE default argument pattern is:
  --raw="{out}" "{src}"

That builds a raw CP/M .COM-style binary from an org 100h source file. The IDE then converts that .COM to Intel HEX at address 0100h.

Upstream:
  https://github.com/z00m128/sjasmplus
