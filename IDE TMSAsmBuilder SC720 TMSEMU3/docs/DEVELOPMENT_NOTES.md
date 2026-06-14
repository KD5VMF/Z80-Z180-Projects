# Development Notes

## Build model

The IDE builds a CP/M program in these steps:

1. Save the current editor text to the selected `.ASM` path.
2. Create a private temporary build folder under `TMSAsmBuilder/Work`.
3. Copy shared `Libs/*.asm` only into that temporary folder.
4. Copy the user program into the temporary folder.
5. Run `sjasmplus.exe` using the default pattern:

```text
--raw="{out}" "{src}"
```

6. If the `.COM` is created, convert it to Intel HEX records at address `0100h`.
7. Copy the latest `.COM`, `.ASM`, and `.HEX` to `TMSAsmBuilder/Out`.
8. Copy only `.ASM` and `.HEX` to the clean timestamped folder under `TMSAsmBuilder/Builds`.
9. Delete the private temporary build folder.

## Why the clean build folders do not include libs

The clean build folders are meant to be the user-facing result: just the final program source and text-transfer HEX file.

The shared libraries remain in `TMSAsmBuilder/Libs`, so the repo does not produce a new duplicate copy of `tms.asm`, `z180.asm`, and `utility.asm` every time the user clicks Build.

## Startup behavior

The editor intentionally starts blank. This prevents a user from accidentally thinking the Bounce Demo is their own active project. The user chooses the source:

- `New ASM`
- `Open ASM`
- `Load Bounce Demo`

## Syntax coloring

The editor is a WinForms `RichTextBox`. Coloring is delayed by a short timer after edits to avoid recoloring on every keystroke.

Current colors:

- comments: green
- labels: teal
- opcodes: blue
- directives: purple
- strings: orange
- numbers: light green

## Template behavior

`Load Bounce Demo` reads `TMSAsmBuilder/Templates/BOUNCE.ASM`. If that file is missing from a custom build, the app has an embedded fallback copy of the demo.

## Included content copied to output

The project file copies these folders to the build/publish output:

- `Assets`
- `Libs`
- `Templates`
- `Tools`

That way `dotnet run`, `dotnet build`, and `dotnet publish` all have the icon, templates, libraries, and assembler available beside the executable.
