# Building / creating HEX+COM

Both prime programs are written in **8080-compatible** assembly (also runs on Z80).

They are already provided as:

- Intel HEX: `hex/`
- CP/M COM binaries: `bin/`  (generated from the HEX files)

## If you want to rebuild yourself

Any assembler that accepts 8080 syntax should work. Because toolchains vary a lot
in the retro world, this repo doesn’t force one specific assembler.

If you generate a new Intel HEX, you can create a `.COM` file with:

```sh
python3 tools/ihex_to_com.py hex/LCDPRIME16.HEX bin/LCDPRIME16.COM
python3 tools/ihex_to_com.py hex/LCDPRIME24.HEX bin/LCDPRIME24.COM
```

The programs are `ORG 0100h`, so the `.COM` files are meant to be loaded at 0100h.
