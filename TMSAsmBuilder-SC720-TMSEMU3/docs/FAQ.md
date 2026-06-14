# FAQ

## Why does this use `sjasmplus` instead of CP/M `ASM.COM`?

The TMS9918A examples use Z80 assembler syntax such as `ld`, `jp`, `jr`, `include`, and `defb`. CP/M `ASM.COM` is an Intel 8080-style assembler and does not understand that source format.

## Why are there two output places?

`Builds` is for clean shareable `.ASM` + `.HEX` project folders.

`Out` is for the latest transfer files, including the `.COM` used by XMODEM.

## Why is the `.COM` not in the clean build folder?

That was intentional. The clean build/project folders are meant to contain only the newly created `.ASM` and `.HEX` files.

## Where do I put library files?

Put shared library/support `.asm` files in:

```text
TMSAsmBuilder/Libs
```

## What if the IDE says `sjasmplus.exe` is missing?

The repo package should include it in:

```text
TMSAsmBuilder/Tools/sjasmplus.exe
```

If it is missing, download `sjasmplus.exe` and put it there, or click **Find sjasmplus.exe** in the IDE.
