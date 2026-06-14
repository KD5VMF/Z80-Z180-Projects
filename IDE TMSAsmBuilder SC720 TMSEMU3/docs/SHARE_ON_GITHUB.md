# Share on GitHub

## Suggested repo name

```text
TMSAsmBuilder-SC720-TMSEMU3
```

## Suggested description

```text
Windows IDE/build tool for SC720/RomWBW CP/M TMS9918A/TMSEMU3 Z80 assembly, with bundled sjasmplus, support libs, and a bouncing sprite demo.
```

## Upload steps

1. Create a new GitHub repository.
2. Extract this ZIP.
3. Copy the extracted files into your local repo folder.
4. Commit everything except generated build output.
5. Push to GitHub.

The `.gitignore` is set up to avoid committing generated build output, bin/obj folders, temporary work folders, and downloaded extract folders.

## Important note about third-party code

This repo bundles third-party files so users can get started quickly:

- `Tools/sjasmplus.exe`
- `Libs/*.asm`

Keep `THIRD_PARTY_NOTICES.md` in the repo when sharing so attribution and license notes stay with the package.
