
# Changelog

## REV8 - GitHub HELP/manual package

- Added top-level `HELP/` folder with a full manual, ChatGPT device brief, ASM writing guide, Tera Term/CP-M transfer guide, troubleshooting, maintainer internals, GitHub sharing text, and credits/links.
- Added `Portable_Windows_App/` as a ready-to-run app folder for ZIP users.
- Added `RUN_PORTABLE_APP.bat`.
- Updated README for public GitHub use.
- Advanced displayed app revision to REV8 while keeping the program name the same.

## REV7 - BALLS.COM output and paste-ready HEX tab

- Kept the same app/repo name and advanced only the REV marker.
- Changed the bundled demo output from `BOUNCE.COM` to `BALLS.COM`.
- Renamed the bundled demo template to `Templates/BALLS.ASM`.
- Added a two-tab source area:
  - **ASM Source** keeps the normal assembly editor.
  - **HEX Paste** shows the full Intel HEX text after a successful build.
- Added **Copy HEX** so the generated HEX can be copied directly for Tera Term paste.
- After a successful build, the IDE switches to the HEX tab and shows the full paste-ready HEX dump.
- Build argument paths are passed to sjasmplus with forward slashes to avoid the sjasmplus backslash filename warning.

## REV6 - Smooth editor and colored build logs

- Reduced editor flicker/full-screen refresh while typing by freezing RichTextBox redraw during syntax coloring and restoring caret/scroll position afterward.
- Replaced the plain build log textbox with a rich log window.
- Build warnings now appear bold gold/yellow.
- Build failures/errors now appear bold red.
- Successful build lines appear bold green.
- Assembler stdout/stderr is classified line-by-line for clearer failed compile logs.

## REV5 - Balls Demo GitHub package

- App now opens with a blank editor and no program loaded.
- Removed the old chess template/demo.
- Added **Load Balls Demo** button.
- Added `Templates/BALLS.ASM` as the bundled demo.
- `New ASM` now starts a blank editor.
- Build action now warns if the editor is empty.
- Project file now copies `Assets`, `Libs`, `Templates`, and `Tools` into build/publish output.
- README and docs rewritten to explain the IDE, Tools folder, Libs folder, Balls Demo, build behavior, and CP/M transfer paths.

## REV4 - IDE color / HEX / clean output

- Added IDE icon.
- Added ASM syntax coloring.
- Added Intel HEX output.
- Kept timestamped build folders clean with only generated `.ASM` and `.HEX`.
- Copied latest `.COM` to `Out` for XMODEM transfer.
- Fixed WinForms `RichTextBox` build issue.
