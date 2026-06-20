# Changelog

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
