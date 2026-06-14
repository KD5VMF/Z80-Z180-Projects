# Changelog

## REV5 GitHub Repo Edition

- Added full GitHub-ready README.
- Added docs for Windows build/run, CP/M transfer, Intel HEX behavior, credits, troubleshooting, and GitHub setup.
- Added NOTICE and CONTRIBUTING files.
- Added `.gitignore` and `.gitattributes`.
- Added `publish_portable.bat`.
- Updated the `.csproj` so `Libs`, `Tools`, `Templates`, and project folder README files copy into the build/publish output.
- Preserved REV4 IDE features: icon, syntax coloring, clean build folders, `.COM` output, and Intel HEX generation.

## REV4 IDE

- Added IDE icon.
- Added ASM syntax coloring.
- Clean timestamped build folders contain only final `.ASM` and `.HEX` files.
- Latest `.COM`, `.ASM`, and `.HEX` copy to `Out`.
- Fixed RichTextBox build issue by removing TextBox-only `AcceptsReturn` usage.
