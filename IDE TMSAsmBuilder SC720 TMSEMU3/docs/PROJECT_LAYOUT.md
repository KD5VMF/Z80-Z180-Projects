# Project Layout

```text
TMSAsmBuilder-SC720-TMSEMU3/
├─ TMSAsmBuilder.sln
├─ TMSAsmBuilder/
│  ├─ MainForm.cs
│  ├─ Program.cs
│  ├─ TMSAsmBuilder.csproj
│  ├─ Assets/
│  │  └─ TMSAsmBuilder.ico
│  ├─ Libs/
│  │  ├─ tms.asm
│  │  ├─ tmsfont.asm
│  │  ├─ z180.asm
│  │  ├─ utility.asm
│  │  └─ extra upstream/example support files
│  ├─ Templates/
│  │  └─ BOUNCE.ASM
│  ├─ Tools/
│  │  └─ sjasmplus.exe
│  ├─ Work/
│  ├─ Builds/
│  └─ Out/
├─ docs/
├─ FIRST_RUN.bat
├─ build_gui.bat
├─ run_gui.bat
└─ publish_win_x64.bat
```

## `TMSAsmBuilder/Tools`

This folder contains the external assembler used by the IDE.

The bundled tool is `sjasmplus.exe`, a Z80-family cross assembler. The IDE invokes it to turn `org 100h` Z80/sjasmplus source into a raw CP/M `.COM` binary.

## `TMSAsmBuilder/Libs`

This folder contains shared ASM include files. Programs can simply say:

```asm
include "tms.asm"
include "z180.asm"
include "utility.asm"
```

During build, the IDE copies these libraries into a private temporary work folder so the assembler can resolve the includes. The public timestamped build folders do not receive copied library files.

## `TMSAsmBuilder/Templates`

This folder contains optional demo/starter programs. The IDE does not load a template automatically on startup.

Current bundled template:

```text
BOUNCE.ASM
```

## `TMSAsmBuilder/Work`

This is where the IDE saves the current working source when you use the default file path.

## `TMSAsmBuilder/Builds`

Each successful build gets a clean timestamped folder. These folders contain only the generated `.ASM` and `.HEX` files.

## `TMSAsmBuilder/Out`

This is the quick-transfer output folder. It gets the latest `.ASM`, `.HEX`, and `.COM` files.
