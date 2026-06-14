# Project layout notes

## `TMSAsmBuilder/Libs`

Shared library/support `.asm` files live here.

They are not copied into timestamped project/build folders.

## `TMSAsmBuilder/Work`

The editor's working file area.

Temporary internal build folders may appear here while building and are deleted after the build completes.

## `TMSAsmBuilder/Builds`

Every successful build creates a timestamped clean folder.

Design rule:

```text
Builds/<PROGRAM>_<timestamp>/
├─ PROGRAM.ASM
└─ PROGRAM.HEX
```

No copied libs. No `.COM` here.

## `TMSAsmBuilder/Out`

Latest output copy. This is the convenience folder for transfer.

Expected files:

```text
PROGRAM.ASM
PROGRAM.COM
PROGRAM.HEX
```

Use the `.COM` here for XMODEM.

## `TMSAsmBuilder/Tools`

Bundled assembler tool location.

The IDE first looks here for:

```text
sjasmplus.exe
sjasm.exe
```

Then it checks the system PATH.
