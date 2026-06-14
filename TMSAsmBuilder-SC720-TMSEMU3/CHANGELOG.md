# Changelog

## REV4 GitHub-ready package

- Added polished repository layout and documentation.
- Added `FIRST_RUN.bat`.
- Added `publish_win_x64.bat`.
- Added `.gitignore`, `.gitattributes`, GitHub Actions workflow, license, and third-party notices.
- Included user docs for CP/M transfer, project layout, and development notes.

## REV4 IDE color + HEX build fix

- Added IDE icon.
- Switched ASM editor to syntax-colored `RichTextBox`.
- Added coloring for comments, labels, opcodes, directives, strings, and numbers.
- Build folders now receive only generated `.ASM` and `.HEX` files.
- The `.COM` is still generated and copied to `Out` for XMODEM transfer.
- Removed invalid `RichTextBox.AcceptsReturn` property assignment.

## REV3 HEX

- Added Intel HEX generation from built `.COM` bytes.
- HEX records start at CP/M `.COM` load address `0100h`.
- HEX ends with standard EOF record `:00000001FF`.
