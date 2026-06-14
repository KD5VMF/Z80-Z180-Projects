# FAQ

## Why does the IDE open blank?

So the user controls what is loaded. Click **Load Bounce Demo**, **Open ASM**, or **New ASM**.

## Where did the chess demo go?

It was removed. The bundled demo is now `BOUNCE.ASM`, a colorful TMS9918A/TMSEMU3 sprite demo.

## Why are library files not copied into each build folder?

They are shared support files. The IDE uses them internally in a temporary build folder, but public build folders are kept clean with only `.ASM` and `.HEX`.

## Where is the `.COM` file?

The `.COM` file is copied to:

```text
TMSAsmBuilder/Out
```

The clean timestamped project folders intentionally contain only `.ASM` and `.HEX`.

## Why do I need `sjasmplus.exe`?

The J.B. Langston-style TMS9918A code uses Z80/sjasmplus-style syntax. CP/M `ASM.COM` is an 8080 assembler and is not the right tool for this source style.

## What if `sjasmplus.exe` is missing?

Put it in:

```text
TMSAsmBuilder/Tools
```

Or click **Find sjasmplus.exe** and point the IDE to it.

## What if the TMSEMU3/TMS9918A is not found?

The Bounce Demo prints an abort message on the CP/M console. Check the video card address/jumpers and make sure the J.B. Langston-style `TmsProbe` routine supports your hardware configuration.

## Can I use my own ASM file?

Yes. Click **Open ASM**, or click **New ASM** and paste/type code. Keep include files in `Libs` or include them with paths that sjasmplus can resolve.
