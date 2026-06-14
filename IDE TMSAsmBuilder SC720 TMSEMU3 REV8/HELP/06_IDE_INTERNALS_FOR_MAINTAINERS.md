# IDE internals for maintainers

This file explains how the IDE works internally so future updates are easier.

## Project type

- Language: C#
- UI: Windows Forms
- Target framework: `net8.0-windows`
- Main source file: `TMSAsmBuilder/MainForm.cs`
- Entry point: `TMSAsmBuilder/Program.cs`

## Startup

The app uses `AppContext.BaseDirectory` as its runtime root. That means paths resolve under the folder containing the running executable when using the portable app, or under the build output folder when running from source.

Runtime folders are created if missing:

```text
Libs
Tools
Out
Work
Builds
```

The IDE intentionally opens with no source loaded.

## Editor

The ASM editor is a `RichTextBox` with simple syntax coloring.

To avoid the whole editor visibly repainting while typing, the code:

- delays colorizing with a short timer,
- remembers caret and scroll position,
- sends `WM_SETREDRAW` false while applying colors,
- restores scroll/caret,
- sends `WM_SETREDRAW` true and invalidates once.

This is why typing should not reload/refresh the whole terminal-looking editor area.

## Source tabs

The upper area is a `TabControl` with:

```text
ASM Source
HEX Paste
```

The HEX tab is read-only. It is cleared when source changes and filled after a successful build.

## Build pipeline

`BuildAsync()` is the main build routine.

Steps:

1. Reject empty source.
2. Save the current ASM.
3. Sanitize the requested `.COM` name.
4. Create a timestamped public build folder under `Builds`.
5. Create a private temp build folder under `Work`.
6. Copy every `Libs/*.asm` file into the temp folder.
7. Write the final public `.ASM` into the timestamped build folder.
8. Copy that `.ASM` into the temp folder.
9. Run the assembler from the temp folder.
10. Capture stdout/stderr.
11. Color-classify log output line by line.
12. If a `.COM` was created, convert it to Intel HEX.
13. Copy latest `.ASM`, `.COM`, and `.HEX` to `Out`.
14. Load HEX into the HEX Paste tab.
15. Delete the temp folder.

## Assembler args

Default:

```text
--raw="{out}" "{src}"
```

Before launching, the IDE replaces:

- `{out}` with the temp `.COM` path,
- `{src}` with the temp `.ASM` path.

Paths are normalized with `/` to avoid sjasmplus warnings about backslashes in filenames.

## Intel HEX conversion

The IDE reads the raw `.COM` bytes and writes Intel HEX records starting at:

```text
0100h
```

Each record is 16 bytes. End-of-file record is:

```text
:00000001FF
```

This output is for CP/M `LOAD`.

## Log coloring

The log is a `RichTextBox`.

Classification rules are intentionally simple:

- words like `error`, `failed`, `fatal`, `undefined`, `not found`, `cannot open`, `invalid` become red/error,
- words like `warn`, `warning`, `caution`, `deprecated` become yellow/warning,
- words like `pass`, `success`, `succeeded`, `built`, `created` become green/success.

Headers are blue.

## Template behavior

The Balls demo is loaded from:

```text
Templates/BALLS.ASM
```

If the template file is missing, the app has an embedded fallback string inside `MainForm.cs`.

## Runtime docs

`EnsureReadmes()` writes small README files into runtime `Libs` and `Tools` folders so users understand those folders even after publish.

## Packaging notes

The `.csproj` copies these folders into build/publish output:

```text
Assets
Libs
Templates
Tools
```

The top-level `Portable_Windows_App` folder is a convenience copy for ZIP users. It is not created by the normal .NET build; it is included in this repo package.

## Things to be careful with

- Keep the app name stable unless intentionally renaming the project.
- Keep REV strings short because existing binary patching, when used, expects same-length replacement.
- Keep default output names CP/M-safe.
- Avoid writing generated temp files into the clean build folders.
- Do not remove the HEX workflow; it is important when XMODEM is not ready.
- Keep the IDE able to run with bundled files and without internet.
