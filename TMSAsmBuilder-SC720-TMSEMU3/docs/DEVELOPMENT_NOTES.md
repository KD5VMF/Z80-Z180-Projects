# Development notes

## Main source file

Most of the app is in:

```text
TMSAsmBuilder/MainForm.cs
```

Important areas:

- WinForms UI setup
- ASM editor syntax coloring
- library import/download
- assembler command execution
- Intel HEX generation
- output folder management

## Syntax coloring

The editor uses a `RichTextBox` and recolors after a short timer delay. This avoids recoloring on every keystroke immediately.

Color categories:

- comments
- quoted strings
- numbers
- labels
- assembler directives
- Z80 opcodes

## Build process

The build flow intentionally separates private build input from public output.

1. Save current editor text.
2. Create a timestamped public folder under `Builds`.
3. Create a private temporary folder under `Work`.
4. Copy shared libs into the temporary folder only.
5. Copy the current program ASM into both places.
6. Run `sjasmplus` in the temporary folder.
7. Convert the temporary `.COM` to Intel HEX.
8. Copy only `.ASM` and `.HEX` into the public build folder.
9. Copy latest `.ASM`, `.COM`, and `.HEX` into `Out`.
10. Delete the private temp folder.

## Important rule

Do not copy library files into the timestamped build/project folders. Those folders are meant for sharing one generated program at a time.
