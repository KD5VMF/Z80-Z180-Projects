# REV10 implementation notes

## Multithreaded work

The build button captures the source text on the UI thread, then calls `Task.Run(...)` for the assembler pipeline.  The UI controls are disabled only for the active build, while the window keeps painting and the Cancel button remains usable.

## Large ASM loading progress

`LargeFileThresholdBytes` is set to 64 KB.  Files at or above that size use an async `FileStream` and update `LoadingForm` as chunks are read.

## Syntax coloring

Syntax coloring is deliberately skipped for very large files.  Full RichTextBox recoloring can be slower than the actual file read, so REV10 favors responsiveness over perfect coloring for big ASM projects.

## Build folders

The temp folder is created under `Work` with `_build_tmp_...`, then removed after success or failure.  The final timestamped build folder is placed under `Builds`, and `Out` mirrors the latest files.
