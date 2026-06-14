# Troubleshooting

## The IDE does not start

### Possible cause: .NET is missing

Install .NET 8 Desktop Runtime or .NET 8 SDK from Microsoft.

Then try:

```text
RUN_PORTABLE_APP.bat
```

or:

```text
FIRST_RUN.bat
```

## Build fails immediately: assembler not found

Make sure this file exists:

```text
TMSAsmBuilder/Tools/sjasmplus.exe
```

or:

```text
Portable_Windows_App/Tools/sjasmplus.exe
```

If it is elsewhere, click **Find sjasmplus.exe**.

## Build fails: cannot open include file

Typical error:

```text
cannot open file tms.asm
```

Check:

```text
TMSAsmBuilder/Libs/tms.asm
TMSAsmBuilder/Libs/z180.asm
TMSAsmBuilder/Libs/utility.asm
```

The source should include them like this:

```asm
include "tms.asm"
include "z180.asm"
include "utility.asm"
```

Do not use full Windows paths in the include lines.

## Build fails with many syntax errors

The source may be written for CP/M `ASM.COM` or another assembler.

This IDE expects Z80/sjasmplus-style source.

Good style:

```asm
        ld      a,1
        jp      z,Done
```

Not the same as Intel 8080-only `ASM.COM` style.

## Program builds but does nothing on the real machine

Check these:

- Is the video card installed and powered?
- Is TMSEMU3/TMS9918A configured at the port expected by `tms.asm`?
- Did the program call `TmsProbe` and continue only if found?
- Is the machine actually running the new `.COM` file?
- Did CP/M `LOAD` produce the `.COM` successfully?
- Was the HEX transfer clean, with `Ctrl-Z` at the end?

## Program says no TMS or blank screen

The demo/program may not find the video chip.

Things to check:

- TMSEMU3 board address/jumper setup.
- RomWBW hardware profile.
- Whether the real system uses the same TMS I/O ports expected by the library.
- Whether TMS wait timing is needed on a fast Z180.

## HEX paste creates a bad file

Symptoms:

- `LOAD` reports errors.
- Program crashes.
- `.COM` size looks wrong.

Fixes:

- Add Tera Term transmit delay.
- Use `5 ms/char` and `50 ms/line` to start.
- Increase delay if needed.
- Make sure you pressed `Ctrl-Z` after the HEX text.
- Do not paste extra prompt text into the file.
- Use the **Copy HEX** button after a fresh successful build.

## XMODEM transfer fails

Check:

- CP/M is running `XM R NAME.COM` before you send.
- Tera Term uses XMODEM send, not text send.
- The file selected is the `.COM`, not the `.HEX`.
- Serial speed/settings are stable.
- Flow control is off unless your hardware actually supports it.

## Output filename gets changed

The IDE sanitizes the output name for CP/M compatibility.

Use short names:

```text
STARS.COM
BALLS.COM
CLOCK.COM
```

Avoid long names, spaces, punctuation, and Windows-only filename habits.

## Build succeeds but old code runs

You may be running an old CP/M file.

On CP/M:

```text
C>ERA BALLS.COM
C>ERA BALLS.HEX
```

Then transfer again.

Also check that you transferred from the correct `Out` folder.

## Log is yellow but build succeeds

A warning is not always fatal. Yellow/gold lines mean the assembler or IDE noticed something worth reading.

Red lines are the important failure lines.

## Log says COM too large

A normal CP/M `.COM` image beginning at `0100h` cannot exceed the available transient program space. The IDE refuses to create nonsensical HEX if the raw binary is too large.

Reduce tables, graphics data, or code size.

## GitHub ZIP users cannot run the source

They need the .NET SDK to build from source.

They can usually run the portable app folder with only the .NET Desktop Runtime.

## Best debugging approach

1. Build and run `BALLS.ASM` first.
2. Change only one thing.
3. Build again.
4. Transfer again.
5. Keep old known-good files in `Builds`.
6. Use short filenames.
7. Read the first red/yellow log lines.
