# Changelog

## REV5 - Bounce Demo GitHub package

- App now opens with a blank editor and no program loaded.
- Removed the old chess template/demo.
- Added **Load Bounce Demo** button.
- Added `Templates/BOUNCE.ASM` as the bundled demo.
- `New ASM` now starts a blank editor.
- Build action now warns if the editor is empty.
- Project file now copies `Assets`, `Libs`, `Templates`, and `Tools` into build/publish output.
- README and docs rewritten to explain the IDE, Tools folder, Libs folder, Bounce Demo, build behavior, and CP/M transfer paths.

## REV4 - IDE color / HEX / clean output

- Added IDE icon.
- Added ASM syntax coloring.
- Added Intel HEX output.
- Kept timestamped build folders clean with only generated `.ASM` and `.HEX`.
- Copied latest `.COM` to `Out` for XMODEM transfer.
- Fixed WinForms `RichTextBox` build issue.
