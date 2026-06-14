# Contributing

Thank you for improving this retro-computing tool.

Good contributions include:

- more SC720 / RomWBW / TMSEMU3 example programs
- better templates
- safer CP/M transfer notes
- syntax highlighting improvements
- bug fixes that keep the IDE simple and dependable

## Style goals

- Keep the program easy for non-professional programmers.
- Prefer complete, working files over tiny patch fragments.
- Avoid hidden magic. Log what the builder is doing.
- Do not let build errors crash or lock the IDE.
- Keep generated build folders clean: final `.ASM` and `.HEX` only.

## Testing before a pull request

On Windows:

```text
build_gui.bat
run_gui.bat
```

Then open the IDE, load the template, and run **Build .COM + .HEX**.

Expected result:

- timestamped folder under `TMSAsmBuilder/Builds`
- that folder contains only `.ASM` and `.HEX`
- latest `.COM` appears under `TMSAsmBuilder/Out`
