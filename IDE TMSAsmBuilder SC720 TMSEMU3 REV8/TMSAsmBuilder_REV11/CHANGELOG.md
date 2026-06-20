# Changelog

## REV11 - Color Editor + Hello World - 2026-06-20

- Added proper ASM source coloring in the C# source editor.
- Added distinct colors for comments, strings, labels, directives, Z80/Z180 instructions, registers, and numbers.
- Re-enabled syntax coloring safely using a debounce timer and caret/scroll restoration so the editor should not snap back upward.
- Changed first-start template to `HELLO.ASM`.
- Added a build-ready CP/M Hello World program as `Templates\HELLO.ASM`, `Templates\NEWPROG.ASM`, and `Work\HELLO.ASM`.
- Updated app title, package version, build scripts, docs, and default messages to REV11.
- Preserved REV10A editor stability, forced scrollbars, safer resizing, and RAM cleanup behavior.

## REV10A - Editor Stability + RAM Cleanup Fix - 2026-06-20

- Disabled live full-document syntax recoloring in the ready-to-run DLL so the ASM editor no longer snaps back upward while scrolling or resizing.
- Added scroll-position preservation around any future syntax-color pass.
- Added safer SplitContainer min sizes and forced editor scrollbars.
- Added automatic cleanup of stale `_build_tmp_*` folders.
- Added log auto-trimming to reduce RAM growth on long sessions.
- Reworked large-file source read path to avoid extra MemoryStream/ToArray copies.
- Added Large Object Heap compaction requests after big loads/builds and on close.

## REV10 Latest IDE Package

- Combined the compiled REV10 IDE, clean source repo, Windows build scripts, assets, tools, libs, templates, work files, and output folders into one portable package.
- Removed Visual Studio transient folders such as `.vs`, `bin`, and `obj` from the source tree.
- Kept the ready-to-run `TMSAsmBuilder.exe` at the package root for simple use.

## REV10 - 2026-06-20

- Added background-thread assembler build so the IDE does not freeze during larger projects.
- Added Cancel button for active builds.
- Added large ASM file loading dialog with progress bar.
- Added async file open/save paths.
- Added large-file-safe syntax highlighting behavior.
- Reorganized project as a clean source repository.
- Removed duplicated old build artifacts from the tracked repo layout.
- Preserved REV9 output behavior: timestamped complete build folders plus latest `Out` mirror.

## REV9

- Placed the final `.COM` in the same timestamped build folder as the matching `.ASM` and `.HEX`.
- Kept newest quick-output files in `Out`.
